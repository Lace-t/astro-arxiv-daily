#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && pwd)"
OPENCLAW_BIN="${OPENCLAW_BIN:-$(command -v openclaw || true)}"

if [[ -f "$ROOT/config.local.sh" ]]; then
  # Keep install-time delivery resolution aligned with run_once.sh.
  # shellcheck disable=SC1091
  source "$ROOT/config.local.sh"
fi

CRON_NAME="${ASTRO_ARXIV_DAILY_JOB_NAME:-astro-arxiv-daily}"
CRON_DESCRIPTION="${ASTRO_ARXIV_DAILY_JOB_DESCRIPTION:-Weekday astro-ph top-3 digest}"
CRON_EXPR="${ASTRO_ARXIV_DAILY_CRON:-30 11 * * 1-5}"
CRON_TZ="${ASTRO_ARXIV_DAILY_TZ:-Asia/Shanghai}"
DELIVERY_CHANNEL="${ASTRO_ARXIV_DAILY_CHANNEL:-openclaw-weixin}"
DELIVERY_ACCOUNT_ID="${ASTRO_ARXIV_DAILY_ACCOUNT_ID:-}"
DELIVERY_TO="${ASTRO_ARXIV_DAILY_TO:-CHANGE_ME@im.wechat}"
PROMPT_FILE="${ASTRO_ARXIV_DAILY_PROMPT_FILE:-$ROOT/references/cron-prompt.md}"

if [[ -z "$OPENCLAW_BIN" || ! -x "$OPENCLAW_BIN" ]]; then
  echo "openclaw_not_found=Set OPENCLAW_BIN or add openclaw to PATH" >&2
  exit 1
fi

if [[ "$DELIVERY_TO" == "CHANGE_ME@im.wechat" ]]; then
  echo "config_incomplete=Set ASTRO_ARXIV_DAILY_TO before installing cron" >&2
  exit 1
fi

if [[ -z "$DELIVERY_ACCOUNT_ID" || "$DELIVERY_ACCOUNT_ID" == "CHANGE_ME_ACCOUNT_ID" ]]; then
  echo "config_incomplete=Set ASTRO_ARXIV_DAILY_ACCOUNT_ID before installing cron" >&2
  exit 1
fi

remove_existing_jobs() {
  local existing_ids
  mapfile -t existing_ids < <(
    "$OPENCLAW_BIN" cron list --json | /usr/bin/python3 -c '
import json
import sys

target_name = sys.argv[1]
data = json.load(sys.stdin)
for job in data.get("jobs", []):
    if job.get("name") == target_name:
        print(job["id"])
' "$CRON_NAME"
  )

  if [[ "${#existing_ids[@]}" -eq 0 ]]; then
    return 0
  fi

  for job_id in "${existing_ids[@]}"; do
    "$OPENCLAW_BIN" cron rm "$job_id" >/dev/null
  done
}

remove_existing_jobs

"$OPENCLAW_BIN" cron add \
  --name "$CRON_NAME" \
  --description "$CRON_DESCRIPTION" \
  --cron "$CRON_EXPR" \
  --tz "$CRON_TZ" \
  --exact \
  --light-context \
  --session isolated \
  --thinking off \
  --announce \
  --channel "$DELIVERY_CHANNEL" \
  --account "$DELIVERY_ACCOUNT_ID" \
  --to "$DELIVERY_TO" \
  --message "$(cat "$PROMPT_FILE")"
