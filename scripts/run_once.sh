#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$ROOT/logs"
OUT_DIR="$ROOT/output"
RUN_DATE="${1:-$(date +%F)}"
SESSION_ID="astro-arxiv-daily-once-${RUN_DATE}-$(date +%H%M%S)"
CANDIDATES_JSON="$LOG_DIR/${RUN_DATE}-candidates.json"
TOP3_CONTEXT_JSON="$LOG_DIR/${RUN_DATE}-top3-context.json"
TOP3_NOTES_TXT="$LOG_DIR/${RUN_DATE}-top3-notes.txt"
PROMPT_FILE="$LOG_DIR/${RUN_DATE}-run-once-prompt.md"
RAW_RESPONSE="$LOG_DIR/${RUN_DATE}-run-once-response.txt"
SCORING_JSON="$LOG_DIR/${RUN_DATE}-scoring.json"
FINAL_OUTPUT="$OUT_DIR/${RUN_DATE}-top3.txt"
OPENCLAW_BIN="${OPENCLAW_BIN:-$(command -v openclaw || true)}"
OPENCLAW_CONFIG="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
CURRENT_MODEL="$(/usr/bin/python3 -c "import json; print(json.load(open('$OPENCLAW_CONFIG'))['agents']['defaults']['model']['primary'])")"
DELIVERY_ENABLED="${ASTRO_ARXIV_DAILY_SEND_WEIXIN:-0}"
DELIVERY_CHANNEL="${ASTRO_ARXIV_DAILY_CHANNEL:-openclaw-weixin}"
DELIVERY_ACCOUNT_ID="${ASTRO_ARXIV_DAILY_ACCOUNT_ID:-}"
DELIVERY_TO="${ASTRO_ARXIV_DAILY_TO:-}"

export PATH="$(dirname "$OPENCLAW_BIN"):/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
unset LD_LIBRARY_PATH

if [[ -z "$OPENCLAW_BIN" || ! -x "$OPENCLAW_BIN" ]]; then
  echo "openclaw_not_found=Set OPENCLAW_BIN or add openclaw to PATH" >&2
  exit 1
fi

if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
  echo "openclaw_config_not_found=$OPENCLAW_CONFIG" >&2
  exit 1
fi

if [[ -f "$ROOT/config.local.sh" ]]; then
  # Allow local delivery settings to be shared by both manual runs and cron-driven runs.
  # shellcheck disable=SC1091
  source "$ROOT/config.local.sh"
  DELIVERY_ENABLED="${ASTRO_ARXIV_DAILY_SEND_WEIXIN:-$DELIVERY_ENABLED}"
  DELIVERY_CHANNEL="${ASTRO_ARXIV_DAILY_CHANNEL:-$DELIVERY_CHANNEL}"
  DELIVERY_ACCOUNT_ID="${ASTRO_ARXIV_DAILY_ACCOUNT_ID:-$DELIVERY_ACCOUNT_ID}"
  DELIVERY_TO="${ASTRO_ARXIV_DAILY_TO:-$DELIVERY_TO}"
fi

mkdir -p "$LOG_DIR" "$OUT_DIR"
cd "$ROOT"

send_weixin_message() {
  local message="$1"
  if [[ "$DELIVERY_ENABLED" != "1" ]]; then
    return 0
  fi
  if [[ -z "$DELIVERY_TO" ]]; then
    echo "delivery_config_incomplete=Set ASTRO_ARXIV_DAILY_TO" >&2
    exit 1
  fi
  if [[ -z "$DELIVERY_ACCOUNT_ID" ]]; then
    echo "delivery_config_incomplete=Set ASTRO_ARXIV_DAILY_ACCOUNT_ID" >&2
    exit 1
  fi
  "$OPENCLAW_BIN" message send \
    --channel "$DELIVERY_CHANNEL" \
    --account "$DELIVERY_ACCOUNT_ID" \
    --target "$DELIVERY_TO" \
    --message "$message" \
    --json >/dev/null
}

send_weixin_message "astro-arxiv-daily 已开始执行 ${RUN_DATE} 的任务。我会在抓取完成、选出 Top 3、以及最终摘要生成后继续通知你。"

bash "$ROOT/scripts/fetch_astro_recent.sh"

/usr/bin/python3 "$ROOT/scripts/build_candidates.py" \
  --recent-html "$LOG_DIR/latest-astro-ph-recent.html" \
  --rss-xml "$LOG_DIR/latest-astro-ph-rss.xml" \
  --hydrate-abstracts \
  --abstract-cache-dir "$LOG_DIR/abstract-cache" \
  --output "$CANDIDATES_JSON"

TODAY_CANDIDATE_COUNT="$(
  /usr/bin/python3 -c "import json; data=json.load(open('$CANDIDATES_JSON')); print(data['total_candidates'])"
)"
send_weixin_message "astro-arxiv-daily 已成功获取今日 arXiv astro-ph 文献，共 ${TODAY_CANDIDATE_COUNT} 篇。"

/usr/bin/python3 "$ROOT/scripts/score_candidates.py" \
  --candidates "$CANDIDATES_JSON" \
  --output "$SCORING_JSON" \
  --date "$RUN_DATE"

mapfile -t TOP3_IDS < <(
  /usr/bin/python3 -c "import json; data=json.load(open('$SCORING_JSON')); print('\n'.join(data['top3']))"
)

send_weixin_message "astro-arxiv-daily 已选出得分最高的 3 篇论文，arXiv 编号分别为：${TOP3_IDS[*]}。"

for arxiv_id in "${TOP3_IDS[@]}"; do
  bash "$ROOT/scripts/fetch_paper_artifacts.sh" "$arxiv_id"
done

/usr/bin/python3 "$ROOT/scripts/build_top3_context.py" \
  --candidates "$CANDIDATES_JSON" \
  --scoring "$SCORING_JSON" \
  --output "$TOP3_CONTEXT_JSON" \
  --final-output "$FINAL_OUTPUT"

/usr/bin/python3 "$ROOT/scripts/extract_paper_notes.py" \
  --top3-context "$TOP3_CONTEXT_JSON" \
  --output "$TOP3_NOTES_TXT"

cat > "$PROMPT_FILE" <<EOF
This is a local one-shot summarization run for astro papers.

Do not use cron.
Do not send to Weixin.
Do not read SKILL.md.
Do not read any HTML files.
Do not use web_fetch.
Work only inside \`${ROOT}\`.

Inputs:
- Template: \`${ROOT}/template.md\`
- Compact paper notes: \`${TOP3_NOTES_TXT}\`

Required output:
- \`${FINAL_OUTPUT}\`

Workflow:
1. Read \`template.md\`.
2. Read \`${TOP3_NOTES_TXT}\`.
3. Produce one standalone plain-text block per paper. There must be 3 paper blocks total.
4. For each paper block, write:
   English Title: ...
   Chinese Title: ...
   arXiv ID: arXiv:...
5. Immediately after those 3 header lines, fill the template in Chinese for that same paper.
6. Keep the same template section wording and order as \`template.md\`, but write the file as plain text, not Markdown prose, not code fences, not JSON.
7. Remove all Markdown heading markers such as \`#\`, \`##\`, \`###\`, and \`####\` from the final output.
8. Do not include the top template title line \`astro-arxiv-daily template\` in the final output.
9. Do not output one shared template for all papers. Each paper must have its own full template body.
10. Use the provided notes to write concrete content. Do not emit generic placeholders like "证据不完整，无法生成详细内容" unless a specific field is truly absent from the notes.
11. If a section is uncertain, say what is uncertain, but still summarize the available evidence.
12. Separate paper blocks with a blank line and a line containing only \`====\`.
13. Do not call the \`write\` tool.
14. Return the full final bundle directly as your final response text only.
EOF

attempt_session_file="${HOME}/.openclaw/agents/main/sessions/${SESSION_ID}.jsonl"
printf 'model_in_use=%s\n' "$CURRENT_MODEL"
: > "$RAW_RESPONSE"
rm -f "$FINAL_OUTPUT"
"$OPENCLAW_BIN" agent \
  --local \
  --session-id "$SESSION_ID" \
  --thinking medium \
  --timeout 1800 \
  --message "$(cat "$PROMPT_FILE")" | tee "$RAW_RESPONSE" || true

if ! /usr/bin/python3 "$ROOT/scripts/extract_session_text.py" \
  --session "$attempt_session_file" \
  --output "$FINAL_OUTPUT" >/dev/null 2>&1; then
  echo "run_once_failed=final_output_not_created" >&2
  exit 1
fi

send_weixin_message "$(<"$FINAL_OUTPUT")"
bash "$ROOT/scripts/cleanup_logs.sh"

printf 'expected_output=%s\n' "$FINAL_OUTPUT"
printf 'logs_cleaned=%s\n' "$LOG_DIR"
