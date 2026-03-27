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
FINAL_OUTPUT="$OUT_DIR/${RUN_DATE}-top3.txt"
OPENCLAW_BIN="${OPENCLAW_BIN:-$(command -v openclaw || true)}"
OPENCLAW_CONFIG="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
CURRENT_MODEL="$(/usr/bin/python3 -c "import json; print(json.load(open('$OPENCLAW_CONFIG'))['agents']['defaults']['model']['primary'])")"
MODEL_CANDIDATES=(
  "sjtu/deepseek-v3.2"
  "sjtu/minimax"
  "sjtu/minimax-m2.5"
  "sjtu/qwen3coder"
  "sjtu/deepseek-reasoner"
  "sjtu/deepseek-chat"
  "vllm-local/Qwen3.5-9B-GPTQ-4bit"
)

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

mkdir -p "$LOG_DIR" "$OUT_DIR"
cd "$ROOT"

restore_model() {
  "$OPENCLAW_BIN" models set "$CURRENT_MODEL" >/dev/null 2>&1 || true
}

trap restore_model EXIT

bash "$ROOT/scripts/fetch_astro_recent.sh"

/usr/bin/python3 "$ROOT/scripts/build_candidates.py" \
  --recent-html "$LOG_DIR/latest-astro-ph-recent.html" \
  --rss-xml "$LOG_DIR/latest-astro-ph-rss.xml" \
  --hydrate-abstracts \
  --abstract-cache-dir "$LOG_DIR/abstract-cache" \
  --output "$CANDIDATES_JSON"

/usr/bin/python3 "$ROOT/scripts/score_candidates.py" \
  --candidates "$CANDIDATES_JSON" \
  --output "$LOG_DIR/${RUN_DATE}-scoring.json" \
  --date "$RUN_DATE"

mapfile -t TOP3_IDS < <(
  /usr/bin/python3 -c "import json; data=json.load(open('$LOG_DIR/${RUN_DATE}-scoring.json')); print('\n'.join(data['top3']))"
)

for arxiv_id in "${TOP3_IDS[@]}"; do
  bash "$ROOT/scripts/fetch_paper_artifacts.sh" "$arxiv_id"
done

/usr/bin/python3 "$ROOT/scripts/build_top3_context.py" \
  --candidates "$CANDIDATES_JSON" \
  --scoring "$LOG_DIR/${RUN_DATE}-scoring.json" \
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

run_succeeded=0
for model_id in "${MODEL_CANDIDATES[@]}"; do
  attempt_session_id="${SESSION_ID}-$(printf '%s' "$model_id" | tr '/.' '__')"
  attempt_session_file="${HOME}/.openclaw/agents/main/sessions/${attempt_session_id}.jsonl"
  "$OPENCLAW_BIN" models set "$model_id" >/dev/null
  printf 'model_attempt=%s\n' "$model_id"
  : > "$RAW_RESPONSE"
  rm -f "$FINAL_OUTPUT"
  "$OPENCLAW_BIN" agent \
    --local \
    --session-id "$attempt_session_id" \
    --thinking medium \
    --timeout 1800 \
    --message "$(cat "$PROMPT_FILE")" | tee "$RAW_RESPONSE" || true
  if /usr/bin/python3 "$ROOT/scripts/extract_session_text.py" \
    --session "$attempt_session_file" \
    --output "$FINAL_OUTPUT" >/dev/null 2>&1; then
    run_succeeded=1
    break
  fi
done

if [[ "$run_succeeded" -ne 1 ]]; then
  echo "run_once_failed=final_output_not_created" >&2
  exit 1
fi

printf 'candidates_json=%s\n' "$CANDIDATES_JSON"
printf 'top3_context_json=%s\n' "$TOP3_CONTEXT_JSON"
printf 'top3_notes_txt=%s\n' "$TOP3_NOTES_TXT"
printf 'prompt_file=%s\n' "$PROMPT_FILE"
printf 'raw_response=%s\n' "$RAW_RESPONSE"
printf 'expected_output=%s\n' "$FINAL_OUTPUT"
printf 'expected_scoring=%s\n' "$LOG_DIR/${RUN_DATE}-scoring.json"
