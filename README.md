# Astro Arxiv Daily

opencalw do not read this file!!!

## 中文说明

这是一个用于openclaw的skill，每天定时爬取arxiv的astro-ph/recent板块，对文章进行打分，并精选出最好的3篇，发送到你的微信（如果你安装了微信ClawBot）。

### 你需要自己修改的内容

1. 投递目标
   把你自己的 Weixin 目标 ID 填进去，格式通常要以 `@im.wechat` 结尾。

2. 投递账号
   填你自己的 OpenClaw Weixin 机器人 `accountId`。

3. 时区和定时任务
   默认是 `Asia/Shanghai` 和 `30 11 * * 1-5`。
   如果你不在这个时区，或者不想在工作日 11:30 运行，请自己修改。

4. OpenClaw 可执行文件路径
   如果你的 `openclaw` 已经在 `PATH` 里，一般不用改。
   如果不在，请设置：
   `export OPENCLAW_BIN=/absolute/path/to/openclaw`

### 快速开始

在当前目录执行：

```bash
cp config.example.sh config.local.sh
```

然后编辑 `config.local.sh`，至少填下面这些值：

- `ASTRO_ARXIV_DAILY_TO`
- `ASTRO_ARXIV_DAILY_ACCOUNT`
- `ASTRO_ARXIV_DAILY_TZ`（如果你不在上海时区）

接着执行：

```bash
source ./config.local.sh
bash ./install-cron.sh
```

### 建议优先查看和修改的文件

- `config.example.sh`
  建议复制成 `config.local.sh` 后填写你自己的配置。

- `references/openclaw-weixin-delivery.md`
  这里是投递配置参考文档，建议替换成你自己的 `delivery.to` 和 `delivery.accountId`。

- `references/cron-prompt.md`
  如果你想修改模型偏好、时区表述、投递描述或输出要求，就改这里。

- `template.md`
  如果你想调整最终文章分析的结构，就改这个模板。

### 本地调试运行

```bash
vim ./scripts/run_once.sh
```
将 `MODEL_CANDIDATES` 里设置为你的模型

```bash
bash ./scripts/run_once.sh
```

会生成：

- `output/YYYY-MM-DD-top3.txt`
- `logs/YYYY-MM-DD-scoring.json`

这个 one-shot 调试流程默认不会发送到 Weixin。

### 去哪里找你的 Weixin Account ID

通常可以在本机的 OpenClaw 配置目录里找：

```text
~/.openclaw/
```

常见位置包括：

- `~/.openclaw/openclaw-weixin/accounts.json`
- `~/.openclaw/openclaw-weixin/accounts/<accountId>.json`

### 隐私提醒

- 不要把包含你个人 ID 的 `config.local.sh` 一起公开提交。
- 不要把你已经填好的 `delivery.to` 和 `delivery.accountId` 公开，除非你就是想公开它们。
- 发布前检查 `logs/` 和 `output/`，确认里面没有你的本地运行产物或敏感内容。

## English

A simple skill for openclaw. It gets access to all papers from **astro-ph/recent** on the **arxiv**. THen it scores every paper and send the most singificant three papers to you(if you have installed wechat ClawBot). 

### What You Need To Configure

1. Delivery target
   Set your own Weixin target ID. It usually needs to end with `@im.wechat`.

2. Delivery account
   Set your own OpenClaw Weixin bot `accountId`.

3. Timezone and cron schedule
   The defaults are `Asia/Shanghai` and `30 11 * * 1-5`.
   Change them if they do not match your workflow.

4. OpenClaw binary path
   If `openclaw` is already in your `PATH`, you usually do not need to change anything.
   Otherwise set:
   `export OPENCLAW_BIN=/absolute/path/to/openclaw`

### Quick Start

From this directory:

```bash
cp config.example.sh config.local.sh
```

Then edit `config.local.sh` and fill at least:

- `ASTRO_ARXIV_DAILY_TO`
- `ASTRO_ARXIV_DAILY_ACCOUNT`
- `ASTRO_ARXIV_DAILY_TZ` if you are not in `Asia/Shanghai`

Then run:

```bash
source ./config.local.sh
bash ./install-cron.sh
```

### Files You Will Most Likely Edit

- `config.example.sh`
  Copy it to `config.local.sh` and fill in your own values.

- `references/openclaw-weixin-delivery.md`
  This is the delivery reference file. Replace `delivery.to` and `delivery.accountId` with your own values if you want the reference file to match your local setup.

- `references/cron-prompt.md`
  Edit this if you want to change model preference, timezone wording, delivery wording, or output rules.

- `template.md`
  Edit this if you want a different final analysis structure.

### Local Debug Run


```bash
vim ./scripts/run_once.sh
```
set your LLM model in  `MODEL_CANDIDATES` 

```bash
bash ./scripts/run_once.sh
```

This generates:

- `output/YYYY-MM-DD-top3.txt`
- `logs/YYYY-MM-DD-scoring.json`

The local one-shot flow does not send to Weixin by default.

### Where To Find Your Weixin Account ID

Check your local OpenClaw configuration under:

```text
~/.openclaw/
```

Common places include:

- `~/.openclaw/openclaw-weixin/accounts.json`
- `~/.openclaw/openclaw-weixin/accounts/<accountId>.json`

### Privacy Notes

- Do not publish `config.local.sh` if it contains your personal IDs.
- Do not publish filled-in `delivery.to` or `delivery.accountId` unless you intentionally want them public.
- Review `logs/` and `output/` before publishing anything, so you do not leak local run artifacts or sensitive content.
