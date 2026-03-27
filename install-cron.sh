#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && pwd)"
OPENCLAW_BIN="${OPENCLAW_BIN:-$(command -v openclaw || true)}"
CRON_NAME="${ASTRO_ARXIV_DAILY_JOB_NAME:-astro-arxiv-daily}"
CRON_DESCRIPTION="${ASTRO_ARXIV_DAILY_JOB_DESCRIPTION:-Weekday astro-ph top-3 digest}"
CRON_EXPR="${ASTRO_ARXIV_DAILY_CRON:-30 11 * * 1-5}"
CRON_TZ="${ASTRO_ARXIV_DAILY_TZ:-Asia/Shanghai}"
DELIVERY_CHANNEL="${ASTRO_ARXIV_DAILY_CHANNEL:-openclaw-weixin}"
DELIVERY_TO="${ASTRO_ARXIV_DAILY_TO:-CHANGE_ME@im.wechat}"
DELIVERY_ACCOUNT="${ASTRO_ARXIV_DAILY_ACCOUNT:-CHANGE_ME_ACCOUNT_ID}"
PROMPT_FILE="${ASTRO_ARXIV_DAILY_PROMPT_FILE:-$ROOT/references/cron-prompt.md}"

if [[ -z "$OPENCLAW_BIN" || ! -x "$OPENCLAW_BIN" ]]; then
  echo "openclaw_not_found=Set OPENCLAW_BIN or add openclaw to PATH" >&2
  exit 1
fi

if [[ "$DELIVERY_TO" == "CHANGE_ME@im.wechat" || "$DELIVERY_ACCOUNT" == "CHANGE_ME_ACCOUNT_ID" ]]; then
  echo "config_incomplete=Set ASTRO_ARXIV_DAILY_TO and ASTRO_ARXIV_DAILY_ACCOUNT before installing cron" >&2
  exit 1
fi

"$OPENCLAW_BIN" cron add \
  --name "$CRON_NAME" \
  --description "$CRON_DESCRIPTION" \
  --cron "$CRON_EXPR" \
  --tz "$CRON_TZ" \
  --exact \
  --session isolated \
  --announce \
  --channel "$DELIVERY_CHANNEL" \
  --to "$DELIVERY_TO" \
  --account "$DELIVERY_ACCOUNT" \
  --message "$(cat "$PROMPT_FILE")"
