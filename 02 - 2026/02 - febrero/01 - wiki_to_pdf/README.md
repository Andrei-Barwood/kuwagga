# Wiki → PDF (with images)

CLI tool that converts wiki/web pages into clean PDFs **with images and full formatting**, using a headless Chromium browser. Ads, navigation, sidebars, cookie banners, and popups are stripped via injected CSS/JS before printing.

## How it works

1. **Launches a headless Chromium browser** (via Playwright) — one instance shared across all URLs.
2. **Fully loads each page** — JavaScript executes, images download, layouts render — exactly as in a real browser.
3. **Auto-dismisses cookie/consent banners** by clicking common "Accept" buttons.
4. **Injects cleanup CSS + JS** that removes ads, navigation, sidebars, footers, sticky bars, tracking overlays, and other clutter. Includes site-specific rules for Fandom/Wikia and Wikipedia/MediaWiki.
5. **Prints to PDF** using Chromium's native PDF engine — high-fidelity output with images, tables, and formatted text.

## Requirements

- **Python 3.10+**
- **Playwright + Chromium**

## Installation

```bash
pip install -r requirements.txt
playwright install chromium
```

## Usage

```bash
python wiki_to_pdf.py
```

The script asks for:

1. **Input file** — path to a `.txt` file with one URL per line.
2. **Output directory** — current directory or a custom path (drag from Finder).

### Input file format

```text
# Lines starting with # are comments
# Blank lines are ignored

https://en.wikipedia.org/wiki/Python_(programming_language)
https://areyouafraidofthedark.fandom.com/wiki/The_Tale_of_the_Night_Nurse
https://en.wikipedia.org/wiki/PDF
```

A sample file is included: `sample_urls.txt`.

## Notes

- PDFs are named after the page title (sanitised for the filesystem).
- If a file already exists, a number is appended: `Title (1).pdf`.
- The browser is launched once and reused for speed.
- There is a 0.3 s delay between pages to be polite to servers.
