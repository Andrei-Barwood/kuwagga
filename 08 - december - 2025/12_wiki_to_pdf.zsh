#!/usr/bin/env zsh

# wiki_to_pdf.zsh
# Convert a list of Fandom (or other) wiki URLs into PDFs for offline reading.
# The script reads URLs from a text file (one URL per line) and saves PDFs
# with images and styling preserved as much as possible.
#
# Usage:
#   ./12_wiki_to_pdf.zsh urls.txt [output_directory]
#
# Example:
#   ./12_wiki_to_pdf.zsh fandom_urls.txt ~/Documents/FandomPDFs
#
# Requirements (at least one of these):
#   - Google Chrome / Chromium / Microsoft Edge with headless mode
#   - OR wkhtmltopdf (from the official site if Homebrew does not provide it)
#
# Reader mode for Fandom:
#   By default, Fandom URLs are fetched through the wiki API and rendered into a
#   clean "article-only" HTML before printing to PDF. This keeps images and text
#   but drops most navigation and clutter.
#   - Requires: python3 and network access when generating PDFs
#   - Disable this behavior by setting:  WIKI_READER_MODE=0

set -u
set -o pipefail

USE_READER_MODE=${WIKI_READER_MODE:-1}

tmp_root=$(mktemp -d -t wiki2pdf.XXXXXX 2>/dev/null || echo "")

cleanup_tmp() {
  if [[ -n "${tmp_root:-}" && -d "${tmp_root:-}" ]]; then
    rm -rf "$tmp_root"
  fi
}

trap cleanup_tmp EXIT INT TERM

script_name=${0:t}

print_usage() {
  cat <<EOF
Usage:
  $script_name urls.txt [output_directory]

urls.txt:
  Text file with one URL per line. Empty lines and lines starting with '#'
  are ignored. Non-http(s) lines are skipped.

output_directory (optional):
  Where to save generated PDFs. Default: ./wiki-pdfs

HTML -> PDF engine:
  This script tries, in order:
    1) Google Chrome (CLI: google-chrome, chromium, or installed app on macOS)
    2) Microsoft Edge (macOS app)
    3) wkhtmltopdf

Install suggestions (macOS):
  - Chrome/Chromium/Edge: Install normally; the script will detect apps in /Applications
  - wkhtmltopdf: If you really need it, download the macOS package from the official
                 wkhtmltopdf project site and install it manually
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  print_usage
  exit 1
fi

urls_file=$1
output_dir=${2:-"./wiki-pdfs"}

if [[ ! -f "$urls_file" ]]; then
  print -u2 "Error: URLs file not found: $urls_file"
  exit 1
fi

if [[ ! -r "$urls_file" ]]; then
  print -u2 "Error: URLs file is not readable (check permissions): $urls_file"
  exit 1
fi

mkdir -p "$output_dir"

###############################################################################
# Detect HTML -> PDF engine
###############################################################################

chrome_bin=""
wkhtml_bin=""

# Try CLI Chrome / Chromium first
if command -v google-chrome &>/dev/null; then
  chrome_bin=$(command -v google-chrome)
elif command -v chromium &>/dev/null; then
  chrome_bin=$(command -v chromium)
fi

# On macOS, also check common app locations
if [[ -z "$chrome_bin" ]]; then
  if [[ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
    chrome_bin="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  elif [[ -x "/Applications/Chromium.app/Contents/MacOS/Chromium" ]]; then
    chrome_bin="/Applications/Chromium.app/Contents/MacOS/Chromium"
  elif [[ -x "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" ]]; then
    chrome_bin="/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
  fi
fi

if command -v wkhtmltopdf &>/dev/null; then
  wkhtml_bin=$(command -v wkhtmltopdf)
fi

if [[ -z "$chrome_bin" && -z "$wkhtml_bin" ]]; then
  print -u2 "Error: No HTML -> PDF engine found."
  print -u2 "Install Google Chrome (or Chromium / Edge), or wkhtmltopdf from the"
  print -u2 "official website if you prefer that engine."
  exit 1
fi

if [[ -n "$chrome_bin" ]]; then
  print "Using browser engine: $chrome_bin"
else
  print "Using wkhtmltopdf: $wkhtml_bin"
fi

###############################################################################
# Helpers
###############################################################################

# Create a safe filename fragment from a URL
sanitize_from_url() {
  local url="$1"
  local path slug

  # Strip protocol
  url="${url#http://}"
  url="${url#https://}"

  # Take path part after domain
  path="${url#*/}"   # naive, but good enough for wikis

  # Remove query string and fragment
  path="${path%%\?*}"
  path="${path%%\#*}"

  [[ -z "$path" ]] && path="page"

  # Replace slashes with underscores
  slug="${path//\//_}"

  # Keep only safe characters for filenames
  slug="${slug//[^A-Za-z0-9._-]/_}"

  # Collapse multiple underscores
  slug="${slug//__/_}"

  print -r -- "$slug"
}

# Generate a unique PDF path, prefixing with index for ordering
# Generate a unique PDF path, prefixing with index for ordering
make_pdf_path() {
  local index="$1"
  local url="$2"
  local base slug candidate

  slug=$(sanitize_from_url "$url")
  base=$(printf '%03d_%s' "$index" "$slug")
  candidate="$output_dir/$base.pdf"

  # If file already exists, append a counter
  local counter=1
  while [[ -e "$candidate" ]]; do
    candidate="$output_dir/${base}_$counter.pdf"
    (( counter++ ))
  done

  print -r -- "$candidate"
}

# Check if a URL points to a Fandom wiki
is_fandom_url() {
  local url="$1"
  local rest host host_l

  rest="${url#*://}"
  host="${rest%%/*}"
  host_l="${host:l}"

  [[ "$host_l" == *.fandom.com ]]
}

# For Fandom URLs, build a cleaner "reader-style" HTML file using the wiki API
make_fandom_reader_html() {
  local url="$1"
  local html_path="$2"

  if [[ -z "$tmp_root" || ! -d "$tmp_root" ]]; then
    return 1
  fi

  if ! command -v python3 &>/dev/null; then
    print -u2 "python3 not found; cannot use Fandom reader mode for: $url"
    return 1
  fi

  python3 - "$url" "$html_path" << 'PY'
import sys, json, html, urllib.parse, urllib.request

if len(sys.argv) != 3:
    raise SystemExit("Usage: make_fandom_reader_html <url> <html_path>")

url = sys.argv[1]
out_path = sys.argv[2]

parsed = urllib.parse.urlparse(url)
if not parsed.scheme or not parsed.netloc:
    raise SystemExit(f"Invalid URL: {url!r}")

base = f"{parsed.scheme}://{parsed.netloc}"
path = parsed.path or "/"

if "/wiki/" in path:
    title_part = path.split("/wiki/", 1)[1]
else:
    title_part = path.strip("/")

if not title_part:
    raise SystemExit(f"Cannot determine page title from {url!r}")

title_for_api = urllib.parse.unquote(title_part)
title_encoded = urllib.parse.quote(title_for_api, safe="")

api_url = f"{base}/api.php?action=parse&page={title_encoded}&format=json&prop=text|displaytitle&redirects=1"

req = urllib.request.Request(api_url, headers={"User-Agent": "wiki_to_pdf.zsh/1.0"})
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode("utf-8", errors="replace"))

parse = data.get("parse") or {}
text = parse.get("text") or {}
html_fragment = text.get("*") or ""
display_title = parse.get("title") or title_for_api.replace("_", " ")

if not html_fragment:
    raise SystemExit(f"API did not return HTML for {url!r}")

doc = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <base href="{html.escape(base)}/">
  <title>{html.escape(display_title)}</title>
  <style>
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      font-size: 14px;
      line-height: 1.6;
      color: #111;
      margin: 1cm;
      background: #ffffff;
    }}
    .wiki-article {{
      max-width: 800px;
    }}
    h1, h2, h3, h4 {{
      font-weight: 600;
      color: #111;
    }}
    a {{
      color: #0645AD;
      text-decoration: none;
    }}
    a:after {{
      content: "";
    }}
    img {{
      max-width: 100%;
      height: auto;
    }}
    /* Hide typical Fandom chrome if it appears inside the fragment */
    .wds-global-navigation,
    .WikiaRail,
    .global-footer,
    .page-header,
    .page-header__actions,
    .page-sidebar,
    .top-ads-container,
    .bottom-ads-container {{
      display: none !important;
    }}
  </style>
</head>
<body>
  <article class="wiki-article">
    {html_fragment}
  </article>
</body>
</html>
"""

with open(out_path, "w", encoding="utf-8") as f:
    f.write(doc)
PY

  return $?
}

convert_with_chrome() {
  local url="$1"
  local pdf_path="$2"

  # --disable-gpu is mostly for older setups; harmless on macOS
  "$chrome_bin" \
    --headless \
    --disable-gpu \
    --print-to-pdf="$pdf_path" \
    --print-to-pdf-no-header \
    "$url"
}

convert_with_wkhtml() {
  local url="$1"
  local pdf_path="$2"

  "$wkhtml_bin" \
    --print-media-type \
    --enable-local-file-access \
    "$url" \
    "$pdf_path"
}

###############################################################################
# Main loop
###############################################################################

print "Reading URLs from: $urls_file"
print "Saving PDFs to:    $output_dir"
print ""

index=0
success_count=0
fail_count=0

# Read all lines from the URLs file into an array (split on newlines)
urls=("${(@f)$(< "$urls_file")}")

for url in "${urls[@]}"; do
  # Remove comments (anything after #)
  url="${url%%#*}"
  # Strip a possible trailing Windows-style CR
  url="${url%$'\r'}"

  # Skip empty lines
  [[ -z "$url" ]] && continue

  # Only process http/https URLs
  if [[ ! "$url" == http://* && ! "$url" == https://* ]]; then
    print "Skipping non-URL line: $url"
    continue
  fi

  (( index++ ))
  pdf_path=$(make_pdf_path "$index" "$url")

  print ""
  print "[$index] Converting:"
  print "  URL : $url"
  print "  PDF : $pdf_path"

  {
    if [[ -n "$chrome_bin" ]]; then
      # Prefer a cleaner "reader-style" view for Fandom if enabled
      if (( USE_READER_MODE )) && is_fandom_url "$url"; then
        html_tmp="$tmp_root/page_${index}.html"
        if make_fandom_reader_html "$url" "$html_tmp"; then
          convert_with_chrome "file://$html_tmp" "$pdf_path"
        else
          print -u2 "Fandom reader mode failed, falling back to direct page for: $url"
          convert_with_chrome "$url" "$pdf_path"
        fi
      else
        convert_with_chrome "$url" "$pdf_path"
      fi
    else
      convert_with_wkhtml "$url" "$pdf_path"
    fi
  } && {
    (( success_count++ ))
    print "  -> OK"
  } || {
    (( fail_count++ ))
    print -u2 "  -> FAILED"
  }

done

print ""
print "Done."
print "  Successful: $success_count"
print "  Failed:     $fail_count"
print "  Output dir: $output_dir"


