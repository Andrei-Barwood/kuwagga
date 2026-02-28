#!/usr/bin/env python3
"""
wiki_to_pdf.py — Convert wiki/web URLs to clean PDFs.

Uses a real headless browser (Playwright/Chromium) to fully load each page
— JavaScript, images, formatting and all — then injects CSS/JS to strip
ads, navigation, sidebars, popups, and cookie banners before printing
to PDF natively via the browser engine.

Usage:
    python wiki_to_pdf.py

Requirements:
    pip install playwright
    playwright install chromium
"""

import os
import re
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright, Page, Browser


# ── Colours ──────────────────────────────────────────────────────────────────

class C:
    HEADER = "\033[95m"
    BLUE   = "\033[94m"
    CYAN   = "\033[96m"
    GREEN  = "\033[92m"
    YELLOW = "\033[93m"
    RED    = "\033[91m"
    BOLD   = "\033[1m"
    DIM    = "\033[2m"
    RESET  = "\033[0m"


def col(text: str, colour: str) -> str:
    return f"{colour}{text}{C.RESET}"


# ── CSS injected into every page to hide junk before printing ────────────────

CLEANUP_CSS = """
/* ── Global ad / tracking / cookie / navigation selectors ── */
[class*="ad-" i], [class*="ad_" i], [class*="advert" i],
[class*="banner" i]:not([class*="article" i]),
[id*="ad-" i], [id*="ad_" i], [id*="advert" i],
[class*="cookie" i], [id*="cookie" i],
[class*="consent" i], [id*="consent" i],
[class*="gdpr" i], [id*="gdpr" i],
[class*="popup" i], [id*="popup" i],
[class*="modal" i]:not([class*="content" i]), [id*="modal" i],
[class*="overlay" i], [id*="overlay" i],
[class*="newsletter" i], [id*="newsletter" i],
[class*="promo" i], [id*="promo" i],
[class*="social" i], [id*="social" i],
[class*="share" i]:not([class*="sharepoint" i]), [id*="share" i],
[class*="sidebar" i], [id*="sidebar" i],
[class*="rail" i], [id*="rail" i],
[class*="related" i], [id*="related" i],
[class*="recommended" i], [id*="recommended" i],
[class*="sticky" i], [class*="floating" i],
[class*="notification" i], [id*="notification" i],
[role="banner"], [role="navigation"], [role="complementary"],
nav, aside, footer,
header:not(.page-header):not(.mw-header),

/* ── Fandom / Wikia specific ── */
.fandom-community-header,
.page-header__actions,
.wiki-page-header__aside,
.top-ads-container,
.bottom-ads-container,
.ad-slot, .ad-slot-placeholder,
.gpt-ad, .ad-holder,
.global-navigation,
.fandom-sticky-header,
.page-footer, .global-footer,
.wds-global-footer,
.wds-global-navigation,
.wiki-notifications,
.notifications-placeholder,
.mcf-wrapper,
.is-right-rail-visible .right-rail-wrapper,
.right-rail-wrapper,
.page__right-rail,
.recirculation,
.fandom-modal,
.featured-video,
.featured-video__wrapper,
.article-video,
[data-tracking-opt-in-overlay],
[data-tracking-opt-in-accept],
.tracking-opt-in-overlay,
.unified-search__layout,

/* ── Wikipedia / MediaWiki specific ── */
.noprint, .printfooter, .catlinks,
.mw-jump-link, .mw-indicators,
.mw-editsection, .navbox, .vertical-navbox,
.metadata, .sistersitebox, .side-box,
#mw-navigation, #mw-head, #mw-panel,
#footer, #siteSub, #contentSub,
.mw-authority-control,

/* ── Generic junk ── */
iframe, .video-player, .embed-video,
[data-ad], [data-ads], [data-ad-slot],
.grecaptcha-badge,
.skip-link, .screen-reader-text,

/* ── Force body to be clean ── */
body {
    overflow: visible !important;
    position: static !important;
}
html {
    overflow: visible !important;
}

/* ── Print-friendly styling ── */
@media print {
    body { font-size: 11pt; line-height: 1.5; }
    img { max-width: 100% !important; height: auto !important; page-break-inside: avoid; }
    table { page-break-inside: auto; }
    tr { page-break-inside: avoid; }
    h1, h2, h3, h4 { page-break-after: avoid; }
    a { color: #1a0dab !important; text-decoration: none !important; }
    a[href]::after { content: none !important; }
}
"""

# ── JavaScript injected to aggressively clean up the DOM ─────────────────────

CLEANUP_JS = """
() => {
    // 1. Remove elements that are display:none or visibility:hidden overlays
    //    but keep the main content
    const removeSelectors = [
        // Ads & tracking
        'ins.adsbygoogle', '.ad-slot', '[data-ad]', '[data-ads]',
        '[id*="google_ads"]', '[id*="taboola"]', '[id*="outbrain"]',
        '.taboola', '.outbrain',
        // Cookie / consent / modals
        '[class*="cookie-banner"]', '[class*="consent-banner"]',
        '[id*="onetrust"]', '.onetrust-consent-sdk',
        '[class*="privacy"]',
        // Fandom specifics
        '.top-ads-container', '.bottom-ads-container',
        '.global-navigation', '.fandom-community-header',
        '.fandom-sticky-header', '.page-footer', '.global-footer',
        '.wds-global-footer', '.wds-global-navigation',
        '.right-rail-wrapper', '.page__right-rail',
        '.recirculation', '.featured-video',
        '.featured-video__wrapper', '.article-video',
        '.mcf-wrapper', '.wiki-notifications',
        '.notifications-placeholder', '.unified-search__layout',
        // Generic
        'iframe:not([src*="youtube"]):not([src*="vimeo"])',
    ];

    for (const sel of removeSelectors) {
        document.querySelectorAll(sel).forEach(el => el.remove());
    }

    // 2. Remove fixed/sticky positioned elements (nav bars, floating ads)
    document.querySelectorAll('*').forEach(el => {
        const style = window.getComputedStyle(el);
        if (style.position === 'fixed' || style.position === 'sticky') {
            // Don't remove if it IS the main content
            if (!el.querySelector('article') && el.tagName !== 'ARTICLE' &&
                !el.querySelector('.mw-parser-output') &&
                !el.classList.contains('mw-parser-output')) {
                el.remove();
            }
        }
    });

    // 3. Remove zero-height / zero-width ad containers
    document.querySelectorAll('div, section, aside').forEach(el => {
        const rect = el.getBoundingClientRect();
        const text = el.innerText || '';
        if (rect.height < 5 && text.trim().length === 0) {
            el.remove();
        }
    });

    // 4. Enable scroll on body (sites sometimes lock it for modals)
    document.documentElement.style.overflow = 'visible';
    document.body.style.overflow = 'visible';
    document.body.style.position = 'static';

    // 5. Get the page title
    const h1 = document.querySelector('h1');
    const ogTitle = document.querySelector('meta[property="og:title"]');
    return h1?.innerText || ogTitle?.content || document.title || 'Untitled';
}
"""


# ── Helpers ──────────────────────────────────────────────────────────────────

def banner():
    print()
    print(col("╔══════════════════════════════════════════════╗", C.CYAN))
    print(col("║         Wiki → PDF  (with images)           ║", C.CYAN))
    print(col("╚══════════════════════════════════════════════╝", C.CYAN))
    print()


def sanitise_filename(title: str) -> str:
    """Turn a page title into a safe filename."""
    name = re.sub(r'[\\/*?:"<>|]', '', title)
    name = re.sub(r'\s+', ' ', name).strip()
    if len(name) > 120:
        name = name[:120].rsplit(' ', 1)[0]
    return name or "untitled"


def read_urls(filepath: str) -> list[str]:
    """Read URLs from a text file (one per line), skip blanks & comments."""
    path = Path(filepath).expanduser().resolve()
    if not path.is_file():
        print(col(f"  ✗ File not found: {path}", C.RED))
        sys.exit(1)

    urls: list[str] = []
    with open(path, "r", encoding="utf-8") as fh:
        for raw_line in fh:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            urls.append(line)

    if not urls:
        print(col("  ✗ No URLs found in the file.", C.RED))
        sys.exit(1)

    return urls


def unique_pdf_path(directory: str, name: str) -> Path:
    """Return a non-colliding PDF path in `directory`."""
    pdf = Path(directory) / f"{name}.pdf"
    counter = 1
    original = pdf
    while pdf.exists():
        pdf = original.with_stem(f"{original.stem} ({counter})")
        counter += 1
    return pdf


# ── Core: load page in browser, clean it, print to PDF ──────────────────────

def inject_css_via_js(page: Page, css: str):
    """
    Inject CSS by creating a <style> element via JavaScript.
    This bypasses Content Security Policy restrictions that block
    page.add_style_tag().
    """
    escaped = css.replace("\\", "\\\\").replace("`", "\\`").replace("${", "\\${")
    page.evaluate(f"""
        () => {{
            const style = document.createElement('style');
            style.textContent = `{escaped}`;
            document.head.appendChild(style);
        }}
    """)


def convert_url_to_pdf(page: Page, url: str, output_dir: str) -> tuple[str, Path]:
    """
    Navigate to `url`, wait for content + images, inject cleanup,
    and save to PDF.  Returns (title, pdf_path).
    """
    # 1. Navigate — use 'domcontentloaded' instead of 'networkidle'
    #    because ad-heavy sites (Fandom) load trackers forever and
    #    'networkidle' times out waiting for them.
    page.goto(url, wait_until="domcontentloaded", timeout=60_000)

    # 2. Wait for the main article content to appear
    #    Try several common content selectors; fall back to a timed wait.
    content_selectors = [
        ".mw-parser-output",        # MediaWiki / Wikipedia / Fandom
        ".page-content",            # Fandom alternative
        "article",                  # Generic semantic HTML
        "#content",                 # Common id
        "#mw-content-text",         # MediaWiki
        "main",                     # Semantic HTML
    ]
    content_found = False
    for sel in content_selectors:
        try:
            page.wait_for_selector(sel, timeout=15_000)
            content_found = True
            break
        except Exception:
            continue

    if not content_found:
        # Last resort: just wait a few seconds for whatever loads
        page.wait_for_timeout(5000)

    # 3. Extra wait for images to lazy-load
    page.wait_for_timeout(3000)

    # 4. Dismiss common cookie / consent banners by clicking accept buttons
    consent_selectors = [
        'button[id*="accept" i]',
        'button[class*="accept" i]',
        'button[class*="agree" i]',
        'button[class*="consent" i]',
        'button[aria-label*="accept" i]',
        'button[aria-label*="agree" i]',
        '[data-tracking-opt-in-accept]',
        '.cookie-accept',
        '#onetrust-accept-btn-handler',
    ]
    for sel in consent_selectors:
        try:
            btn = page.query_selector(sel)
            if btn and btn.is_visible():
                btn.click()
                page.wait_for_timeout(500)
                break
        except Exception:
            pass

    # 5. Inject cleanup CSS via JavaScript (bypasses CSP restrictions)
    inject_css_via_js(page, CLEANUP_CSS)

    # 6. Inject cleanup JS — also returns the page title
    title = page.evaluate(CLEANUP_JS) or "Untitled"

    # 7. Small pause for reflow after cleanup
    page.wait_for_timeout(500)

    # 8. Determine output path
    safe_name = sanitise_filename(title)
    pdf_path = unique_pdf_path(output_dir, safe_name)

    # 9. Print to PDF using the browser engine (Chromium CDP)
    page.pdf(
        path=str(pdf_path),
        format="A4",
        margin={"top": "2cm", "right": "2cm", "bottom": "2cm", "left": "2cm"},
        print_background=True,
    )

    return title, pdf_path


# ── Interactive prompts ──────────────────────────────────────────────────────

def ask_input_file() -> str:
    print(col("  Step 1 — Input file", C.BOLD))
    print("  Paste or type the path to the text file that contains the URLs.")
    print(col("  (You can drag the file from Finder into the terminal)\n", C.DIM))
    while True:
        raw = input(col("  ▸ URL file path: ", C.CYAN)).strip().strip("'\"")
        path = Path(raw).expanduser().resolve()
        if path.is_file():
            print(col(f"  ✓ Using: {path}\n", C.GREEN))
            return str(path)
        print(col(f"  ✗ Not a valid file: {path}. Try again.\n", C.RED))


def ask_output_dir() -> str:
    print(col("  Step 2 — Output directory", C.BOLD))
    print("  Where should the PDF files be saved?\n")
    print(f"    {col('[1]', C.YELLOW)}  Current directory ({os.getcwd()})")
    print(f"    {col('[2]', C.YELLOW)}  Paste a custom path (e.g. from Finder)\n")

    while True:
        choice = input(col("  ▸ Choose [1/2]: ", C.CYAN)).strip()
        if choice == "1":
            out = os.getcwd()
            print(col(f"  ✓ Output: {out}\n", C.GREEN))
            return out
        elif choice == "2":
            raw = input(col("  ▸ Output path: ", C.CYAN)).strip().strip("'\"")
            out_path = Path(raw).expanduser().resolve()
            if out_path.is_dir():
                print(col(f"  ✓ Output: {out_path}\n", C.GREEN))
                return str(out_path)
            create = input(
                col("  ? Directory does not exist. Create it? [y/N]: ", C.YELLOW)
            ).strip().lower()
            if create in ("y", "yes"):
                out_path.mkdir(parents=True, exist_ok=True)
                print(col(f"  ✓ Created & using: {out_path}\n", C.GREEN))
                return str(out_path)
            print(col("  ✗ Try again.\n", C.RED))
        else:
            print(col("  ✗ Please enter 1 or 2.\n", C.RED))


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    banner()

    # 1. Interactive setup
    input_file = ask_input_file()
    output_dir = ask_output_dir()

    # 2. Read URLs
    urls = read_urls(input_file)
    total = len(urls)
    print(col(f"  Found {total} URL(s) to process.", C.BLUE))
    print(col("  Launching headless browser …\n", C.DIM))

    # 3. Launch browser ONCE, reuse across all URLs
    successes = 0
    failures: list[tuple[str, str]] = []

    with sync_playwright() as pw:
        browser: Browser = pw.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            ),
            viewport={"width": 1280, "height": 900},
            locale="en-US",
            bypass_csp=True,  # Bypass Content Security Policy so we can inject CSS/JS
        )

        for idx, url in enumerate(urls, start=1):
            label = f"[{idx}/{total}]"
            print(f"  {col(label, C.BOLD)} {col(url, C.DIM)}")

            page = context.new_page()
            try:
                print("         Loading page …")
                title, pdf_path = convert_url_to_pdf(page, url, output_dir)
                print(col(f"         ✓ Saved: {pdf_path.name}", C.GREEN))
                successes += 1

            except Exception as exc:
                msg = str(exc)
                # Truncate very long Playwright error messages
                if len(msg) > 200:
                    msg = msg[:200] + " …"
                print(col(f"         ✗ {msg}", C.RED))
                failures.append((url, msg))
            finally:
                page.close()

            print()
            if idx < total:
                time.sleep(0.3)

        browser.close()

    # 4. Summary
    print(col("  ── Summary ──────────────────────────────────", C.CYAN))
    print(f"    Total:     {total}")
    print(col(f"    Succeeded: {successes}", C.GREEN))
    if failures:
        print(col(f"    Failed:    {len(failures)}", C.RED))
        for furl, reason in failures:
            print(col(f"      • {furl}", C.RED))
            print(col(f"        {reason}", C.DIM))
    print()
    print(col("  Done ✓", C.GREEN))
    print()


if __name__ == "__main__":
    main()
