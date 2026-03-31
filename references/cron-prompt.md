Run this job with minimal reasoning.

Do exactly the following from the skill root and do not improvise:

1. `cd ~/skills/astro-arxiv-daily`
2. If `config.local.sh` exists, source it.
3. Export `ASTRO_ARXIV_DAILY_SEND_WEIXIN=1`.
4. Run `bash scripts/run_once.sh`.

Rules:

- Treat `scripts/run_once.sh` as the single source of truth for this job.
- Do not read `SKILL.md`, `README.md`, or other documentation unless the script is missing.
- Do not restate the task, do not inspect the directory first, and do not reinterpret the workflow.
- Do not manually reproduce steps that already exist in `scripts/run_once.sh`.
- Do not switch models. Use the current OpenClaw default model at runtime.
- If the script succeeds, return a short plain-text status summary only.
- If the script fails, return the failing step and the relevant error only.
