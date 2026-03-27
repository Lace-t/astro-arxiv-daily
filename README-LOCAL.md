Install the scheduled job with:

```bash
bash ./install-cron.sh
```

Useful checks:

```bash
openclaw gateway status
openclaw cron list --all --json
openclaw cron run <job-id>
bash ./scripts/fetch_astro_recent.sh
```

For this OpenClaw version, `openclaw cron run` accepts the cron job `id`, not the human-readable `name`.

The generated daily digest is plain text for delivery, so the local final artifact path is `output/YYYY-MM-DD-top3.txt`.

After the digest has been successfully sent, clean transient run artifacts with:

```bash
bash ./scripts/cleanup_logs.sh
```

Common fetch behavior:

- Direct `curl` to `https://arxiv.org/list/astro-ph/recent` works.
- Direct `curl` to `https://arxiv.org/rss/astro-ph` works.
- `web_fetch` against arXiv may fail in some OpenClaw environments.
- `export.arxiv.org` API may return `Rate exceeded`.

If cron installation fails, check that your local OpenClaw Gateway is running and reachable before retrying.

Before installing cron, set your own target values with environment variables such as:

```bash
export ASTRO_ARXIV_DAILY_TO="YOUR_TARGET@im.wechat"
export ASTRO_ARXIV_DAILY_ACCOUNT="YOUR_ACCOUNT_ID"
export ASTRO_ARXIV_DAILY_TZ="Asia/Shanghai"
bash ./install-cron.sh
```
