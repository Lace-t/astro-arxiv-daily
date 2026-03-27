Use $astro-arxiv-daily from the current skill directory.

At every weekday 11:30 in Asia/Shanghai time, fetch all recent `astro-ph` papers from arXiv, score every paper on novelty, results conviction, and importance, select the top 3 by total score, and generate a detailed Chinese analysis for each selected paper by following `template.md` exactly.

Model preference:
- Prefer `sjtu/deepseek-v3.2`.
- If `sjtu/deepseek-v3.2` is temporarily unavailable, fall back to another working model only if needed to complete the run.

For arXiv retrieval:
- Do not start with `web_fetch` against arXiv URLs.
- Do not use `export.arxiv.org` API as the primary source.
- First run `bash scripts/fetch_astro_recent.sh` from the skill root.
- Use `logs/latest-astro-ph-recent.html` as the primary source of the full daily candidate list.
- Use `logs/latest-astro-ph-rss.xml` only as a fallback or cross-check.
- Parse and score only the first `today` section in `latest-astro-ph-recent.html`. Do not process older sections from the same page.
- Treat the `today` section count as the only true candidate count for this run.
- If you inspect the full HTML or full RSS file, do not report their raw entry totals as papers processed. Those are source file totals, not the scoped daily workload.
- If RSS is used, match RSS entries only against today's arXiv IDs and report that as `matched RSS abstracts for today's candidates`, not as a separate paper count.
- Status updates must keep these numbers distinct:
  - `today candidates`: papers in today's `astro-ph` section
  - `rss matches`: today's candidates that found an RSS abstract
  - `papers scored`: papers actually scored after scoping to today's section
- A status line like `Parsed 445 total articles` or `Retrieved 134 paper abstracts from RSS` is misleading here and must not be used unless it is explicitly labeled as raw source-file size.

For each selected paper, the outbound message must include:
- English Title
- Chinese Title
- arXiv ID

Then append the full filled template body for that paper as plain text.
Do not include Markdown heading markers like `#`, `##`, `###`, or `####` in the final txt output.
Do not include the top template title line `astro-arxiv-daily template` in the final txt output.

Use `references/openclaw-weixin-delivery.md` for the current Weixin delivery values.
Save final output to `output/YYYY-MM-DD-top3.txt` and scoring notes to `logs/YYYY-MM-DD-scoring.json`.
After a successful Weixin delivery, run `bash scripts/cleanup_logs.sh` so `logs/` is cleared back down to `.gitkeep`.
