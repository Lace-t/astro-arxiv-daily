#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$ROOT/logs"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0 Safari/537.36"
RECENT_URL="https://arxiv.org/list/astro-ph/recent?skip=0&show=2000"
RSS_URL="https://arxiv.org/rss/astro-ph"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
unset LD_LIBRARY_PATH

mkdir -p "$LOG_DIR"

/usr/bin/curl -L -A "$UA" -s "$RECENT_URL" > "$LOG_DIR/latest-astro-ph-recent.html"
/usr/bin/curl -L -A "$UA" -s "$RSS_URL" > "$LOG_DIR/latest-astro-ph-rss.xml"

printf 'recent_html=%s\n' "$LOG_DIR/latest-astro-ph-recent.html"
printf 'rss_xml=%s\n' "$LOG_DIR/latest-astro-ph-rss.xml"
