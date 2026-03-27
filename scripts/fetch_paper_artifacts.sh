#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <arxiv-id>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PAPER_DIR="$ROOT/logs/papers"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0 Safari/537.36"
ARXIV_ID="$1"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
unset LD_LIBRARY_PATH

mkdir -p "$PAPER_DIR"

/usr/bin/curl -L -A "$UA" -s "https://arxiv.org/abs/${ARXIV_ID}" > "$PAPER_DIR/${ARXIV_ID}.abs.html"

if ! /usr/bin/curl -L -A "$UA" -s "https://arxiv.org/html/${ARXIV_ID}v1" > "$PAPER_DIR/${ARXIV_ID}.full.html"; then
  :
fi

printf 'abs_html=%s\n' "$PAPER_DIR/${ARXIV_ID}.abs.html"
printf 'full_html=%s\n' "$PAPER_DIR/${ARXIV_ID}.full.html"
