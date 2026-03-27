---
name: astro-arxiv-daily
description: Fetch, rank, analyze, and deliver a weekday arXiv astrophysics digest for OpenClaw. Use when the user wants a recurring or on-demand workflow that reads the latest papers from arXiv astro-ph recent submissions, scores each paper on novelty, results conviction, and importance, selects the top three papers, fills a strict analysis template from template.md, and prepares the finished summaries for a configurable delivery channel.
---

# Astro Arxiv Daily

Use this skill only inside its own directory and keep all temporary notes, output files, and generated artifacts there.

## Hard Constraints

- Treat `template.md` as the output contract. Follow its headings exactly and keep their order unchanged.
- Run on weekdays at `11:30` in the user's local timezone unless the user explicitly overrides it.
- Source scope is `astro-ph` recent papers from arXiv.
- Final delivery must include, for each selected paper:
  - English title
  - Chinese title if available; otherwise translate the English title
  - arXiv identifier in `arXiv:YYMM.NNNNN` style when possible
- Select exactly 3 papers unless fewer valid astro-ph recent papers exist.
- If the active runtime cannot actually send to the configured delivery channel, stop after preparing the final message bundle and tell the user what is missing.

## Default Workflow

1. Confirm the working directory is the skill root.
2. Read `template.md` before generating any analysis.
3. Retrieve the current `astro-ph` recent paper list from arXiv.
4. Build a candidate table for every paper with:
   - arXiv ID
   - English title
   - authors
   - abstract
   - PDF URL
   - submission date
5. Quickly evaluate every candidate.
6. Rank candidates by the scoring rubric below.
7. Pick the top 3 papers.
8. For each selected paper, read enough material to fill the full template:
   - always read abstract
   - read introduction and conclusion when available
   - read method/results sections if needed to judge evidence strength
9. Generate one completed template per paper.
10. Assemble the delivery payload.
11. Send the message through the configured OpenClaw delivery capability.
12. Save the final artifacts under this skill directory.

## Retrieval Rules

- Prefer arXiv official feeds or pages over third-party summaries.
- Use the `astro-ph/recent` listing as the daily source of truth.
- Prefer local `exec` with `curl` or an equivalent HTTP client over scraped mirror sites.
- Avoid relying on `https://export.arxiv.org/api/query` as the primary source when the recent listing is available.
- First try:
  - `bash scripts/fetch_astro_recent.sh`
- This script saves:
  - `logs/latest-astro-ph-recent.html`
  - `logs/latest-astro-ph-rss.xml`
- The fetch script must request the `recent` page with `show=2000` so the local HTML file contains the full current listing instead of only the first page.
- Parse only the first `today` section from the recent HTML page for the daily candidate set. Ignore older sections that appear later on the same page.
- Use the RSS file only as a fallback or quick cross-check for title, abstract, and arXiv ID extraction.
- If you read the full RSS feed, only count entries that match today's candidate IDs as relevant to the run.
- If the recent page is long, collect all paper entries first, then score.
- If a PDF cannot be read, fall back to the abstract and clearly lower the confidence of the scoring.

## Progress Reporting Rules

- Keep source-file totals separate from scoped run totals.
- Report `today candidates` as the number of papers in today's `astro-ph` section.
- Report `papers scored` as the number of today's candidates that actually entered the scorer.
- Report `rss matches` as the number of today's candidates whose abstracts were filled from RSS.
- Do not present raw totals such as the full `recent.html` entry count or the full RSS item count as if they were the workload for the run.
- Avoid status text like `Parsed 445 total articles` unless it is explicitly framed as `raw source file contains 445 entries across multiple sections`.

## Scoring Rubric

Score each paper on a 1-5 scale for each dimension:

- `Novelty`
  - `5`: introduces a clearly new method, dataset, observation, or interpretation
  - `3`: solid incremental advance or meaningful application
  - `1`: mostly routine extension or limited originality
- `Results Conviction`
  - `5`: evidence is strong, comparisons are clear, conclusions are well supported
  - `3`: evidence is plausible but with notable caveats
  - `1`: claims feel weak, under-tested, or poorly justified
- `Importance`
  - `5`: likely relevant to a broad or high-value astrophysics audience
  - `3`: useful to a narrower subfield
  - `1`: limited impact or niche value

Compute:

- `total_score = novelty + results_conviction + importance`

Tie-breakers in order:

1. higher `importance`
2. higher `novelty`
3. stronger empirical or observational support
4. more recent submission on the same day

## Analysis Rules

- Fill `template.md` exactly. Do not rename headings or add new top-level sections.
- Write the final detailed analysis in Chinese.
- Keep claims grounded in the paper text. Do not invent experimental details, datasets, or conclusions.
- In `### 6. 你对此的评论`, give an actual judgment instead of generic praise.
- In `### 7.本工作可能的延申`, propose realistic follow-up directions.
- When evidence is incomplete, say so explicitly in the relevant section.

## Delivery Format

Prepare one message per paper or one combined message, depending on the available sending tool. In either case, every paper block must begin with:

```text
English Title: ...
Chinese Title: ...
arXiv ID: arXiv:...
```

Then append the fully completed template body for that paper.

If the sending tool supports only plain text, send plain text. Do not rely on Markdown tables.

## OpenClaw Execution Rules

- For scheduled delivery, prefer an exact weekday cron or automation at `11:30` local time instead of a loose polling loop.
- If OpenClaw automation requires a command or prompt body, use this skill from the skill root.
- Configure the actual delivery target for your machine in `references/openclaw-weixin-delivery.md`, `config.local.sh`, or `install-cron.sh`.
- The plugin requires explicit outbound delivery fields for scheduled pushes:
  - `delivery.channel: openclaw-weixin`
  - `delivery.to: <target_user_id@im.wechat>`
  - `delivery.accountId: <weixin_account_id>`
- The target user ID must be a concrete Weixin ID ending with `@im.wechat`.
- If multiple Weixin bot accounts are installed, never rely on implicit account selection for cron delivery. Set `delivery.accountId` explicitly.
- If the Weixin target user identifier is not already configured in the active context, stop and ask for it.
- If needed, inspect your local OpenClaw account files under `~/.openclaw/` to list account IDs and confirm the logged-in bot user.

## Local One-Shot Runner

- For local debugging, use:
  - `bash scripts/run_once.sh`
- This local runner must:
  - refresh the arXiv recent inputs
  - build `logs/YYYY-MM-DD-candidates.json`
  - invoke the skill through `openclaw agent --local`
  - write `output/YYYY-MM-DD-top3.txt`
  - write `logs/YYYY-MM-DD-scoring.json`
- During a local one-shot run, do not send to the delivery channel unless the user explicitly asks for delivery in that run.
- After a successful delivery, clean `logs/` and keep only `.gitkeep`. Use `bash scripts/cleanup_logs.sh`.

## Scheduled Delivery Template

When creating an OpenClaw scheduled task for this skill, use a weekday-only `11:30` schedule in the user's timezone and include an explicit delivery block equivalent to:

```yaml
delivery:
  mode: announce
  channel: openclaw-weixin
  to: "<target_user_id@im.wechat>"
  accountId: "<weixin_account_id>"
timezone: Asia/Shanghai
cron: "30 11 * * 1-5"
```

Use the current user's actual timezone if it differs from `Asia/Shanghai`.

## Files To Maintain

- `template.md`: user-provided required template, never rewrite its structure without explicit instruction.
- `output/`: save generated daily summaries here.
- `logs/`: save scoring snapshots or run notes here when useful.
- `logs/` is transient workspace state. Once the final text has been delivered successfully, clear it back down to `.gitkeep`.

## Minimal Output Layout

When saving local artifacts, use:

- `output/YYYY-MM-DD-top3.txt` for the final plain-text bundle
- `logs/YYYY-MM-DD-scoring.json` for candidate scoring notes

## Failure Handling

- If arXiv is temporarily unavailable, report the failure and do not fabricate content.
- If fewer than 3 papers can be confidently analyzed, send only the valid subset and state why.
- If translation is unavailable, provide a faithful Chinese translation directly in the analysis output.
- If delivery fails, save the final message bundle locally and report the failed delivery step.
