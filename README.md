# Astro Arxiv Daily

## 中文

`astro-arxiv-daily` 是一个 OpenClaw skill，用于从 arXiv 的 `astro-ph/recent` 中挑选当天最值得关注的论文，生成中文摘要，并可选地通过 `openclaw-weixin` 投递给目标用户。

### 工作流

1. 抓取 arXiv `astro-ph/recent` 页面和 RSS。
2. 构建当天论文候选列表。
3. 对候选论文打分并选出 Top 3。
4. 为 Top 3 抓取论文产物并整理紧凑笔记。
5. 使用 OpenClaw 当前默认模型生成最终中文摘要。
6. 如果启用了投递，则通过 `openclaw-weixin` 发送进度通知和最终结果。

这个目录的设计目标是：

- 本地单次运行和定时任务共用同一条主流程
- `scripts/run_once.sh` 是端到端执行的单一事实来源
- 定时任务运行时直接使用用户当前在 OpenClaw 中选择的默认模型
- 投递路由显式配置，避免隐式推断

### 功能特性

- 抓取最新的 arXiv `astro-ph/recent`
- 对候选论文打分并筛出每日 Top 3
- 基于 `template.md` 生成结构化中文摘要
- 同时支持手动运行和 OpenClaw cron 定时运行
- 在启用投递时发送分阶段进度通知
- 成功运行后清理临时日志

### 目录结构

```text
astro-arxiv-daily/
├── README.md
├── SKILL.md
├── config.example.sh
├── config.local.sh
├── install-cron.sh
├── template.md
├── references/
│   ├── cron-prompt.md
│   └── openclaw-weixin-delivery.md
├── scripts/
│   ├── run_once.sh
│   ├── fetch_astro_recent.sh
│   ├── build_candidates.py
│   ├── score_candidates.py
│   ├── fetch_paper_artifacts.sh
│   ├── build_top3_context.py
│   ├── extract_paper_notes.py
│   ├── extract_session_text.py
│   └── cleanup_logs.sh
├── logs/
└── output/
```

### 依赖要求

- 已安装 OpenClaw，且 `openclaw` 在 `PATH` 中可用
- 本机有可用的 OpenClaw 配置文件：`~/.openclaw/openclaw.json`
- 正常运行时需要能访问 arXiv
- 如果需要 Weixin 投递：
  - 已安装并可用 `openclaw-weixin`
  - 已登录一个有效的 Weixin bot 账号
  - 已确认正确的目标用户 ID

### 配置方法

先复制示例配置：

```bash
cp config.example.sh config.local.sh
```

关键变量：

- `ASTRO_ARXIV_DAILY_CHANNEL`
  一般为 `openclaw-weixin`
- `ASTRO_ARXIV_DAILY_ACCOUNT_ID`
  具体用于发送消息的 Weixin bot 账号
- `ASTRO_ARXIV_DAILY_TO`
  插件真实看到的入站目标 ID，通常以 `@im.wechat` 结尾
- `ASTRO_ARXIV_DAILY_TZ`
  cron 使用的时区
- `ASTRO_ARXIV_DAILY_CRON`
  `install-cron.sh` 使用的 cron 表达式
- `ASTRO_ARXIV_DAILY_JOB_NAME`
  OpenClaw cron 任务名称
- `ASTRO_ARXIV_DAILY_JOB_DESCRIPTION`
  任务描述

注意事项：

- `config.local.sh` 属于本机私有配置，不应提交到公开仓库
- `delivery.to` 必须与 `openclaw-weixin` 在该账号下真实观测到的入站 `from_user_id` 完全一致
- `delivery.channel`、`delivery.accountId`、`delivery.to` 应与 `ASTRO_ARXIV_DAILY_CHANNEL`、`ASTRO_ARXIV_DAILY_ACCOUNT_ID`、`ASTRO_ARXIV_DAILY_TO` 表示同一条投递路由

可参考：

- `references/openclaw-weixin-delivery.md`
- `references/cron-prompt.md`

### 快速开始

#### 1. 配置本地变量

```bash
cp config.example.sh config.local.sh
source ./config.local.sh
```

#### 2. 安装 OpenClaw cron 任务

```bash
bash ./install-cron.sh
```

#### 3. 手动运行一次

```bash
bash ./scripts/run_once.sh
```

默认情况下，本地运行只生成文件，不会发送消息。

### 本地运行模式

#### 仅生成输出

```bash
bash ./scripts/run_once.sh
```

预期输出：

- `output/YYYY-MM-DD-top3.txt`
- `logs/YYYY-MM-DD-scoring.json`
- `logs/` 下的中间文件

#### 生成输出并发送 Weixin 通知

```bash
source ./config.local.sh
export ASTRO_ARXIV_DAILY_SEND_WEIXIN=1
bash ./scripts/run_once.sh
```

启用投递后，`run_once.sh` 会发送：

- 开始通知
- 候选论文数量通知
- Top 3 arXiv 编号通知
- 最终正文

### 定时任务模型

`install-cron.sh` 创建的 OpenClaw cron 任务具备以下特性：

- 使用 isolated session
- 使用 light context
- 尽量减少外层 agent 的重复理解
- 直接进入 `scripts/run_once.sh`
- 在运行时读取 OpenClaw 当前默认模型

定时任务的外层提示词位于：

- `references/cron-prompt.md`

### 输出格式

最终摘要写入：

- `output/YYYY-MM-DD-top3.txt`

每篇论文块包含：

- `English Title`
- `Chinese Title`
- `arXiv ID`
- 按 `template.md` 组织的中文分析正文

最终文本由以下脚本从本地 one-shot session 中提取：

- `scripts/extract_session_text.py`

### 重要文件

- `template.md`
  控制最终摘要结构
- `scripts/run_once.sh`
  本地和 cron 共用的主编排脚本
- `install-cron.sh`
  创建 OpenClaw cron 任务
- `config.example.sh`
  对外公开的配置模板
- `references/openclaw-weixin-delivery.md`
  说明 Weixin 投递参数应如何映射

### 故障排查

#### cron 显示 running，但没有实际开始执行

- 检查 `openclaw cron list --json`
- 检查 `~/.openclaw/cron/jobs.json`
- 检查 `~/.openclaw/agents/main/sessions/`

#### 最终输出没有生成

- 检查 `logs/YYYY-MM-DD-run-once-prompt.md`
- 检查 `logs/YYYY-MM-DD-run-once-response.txt`
- 检查 `~/.openclaw/agents/main/sessions/` 中对应的 one-shot session

#### 日志里显示 Weixin 发送成功，但用户没收到

- 确认配置的 `accountId` 仍然存在且已登录
- 确认 `ASTRO_ARXIV_DAILY_TO` 就是该账号对应的真实入站目标 ID
- 确认 bot 账号和目标用户处于同一条有效会话链路

#### Weixin 报 `account not configured`

- 重新检查 `ASTRO_ARXIV_DAILY_ACCOUNT_ID`
- 确认该账号在本机 `openclaw-weixin` 账号存储中真实存在
- 修改配置后重新执行 `install-cron.sh`

### 发布到 GitHub 前

上传前建议确认以下几点：

- 不要提交 `config.local.sh`
- 不要提交已填充的个人 ID、bot 账号 ID 或真实投递目标
- 检查 `logs/` 和 `output/`，清理本地运行产物
- 保持 `config.example.sh` 为通用模板

这个仓库适合公开的是工作流与脚本，不是你的私有投递路由。

---

## English

`astro-arxiv-daily` is an OpenClaw skill for selecting the most interesting papers from arXiv `astro-ph/recent`, generating a Chinese digest, and optionally delivering the result through `openclaw-weixin`.

### Workflow

1. Fetch the current arXiv `astro-ph/recent` page and RSS feed.
2. Build a normalized candidate list for the current day.
3. Score the candidates and select the top 3 papers.
4. Gather paper artifacts and compact notes for the selected papers.
5. Use the current OpenClaw default model to generate the final Chinese digest.
6. Optionally deliver progress updates and the final digest through `openclaw-weixin`.

This directory is designed so that:

- local one-shot runs and scheduled runs share the same core pipeline
- `scripts/run_once.sh` is the single source of truth for the end-to-end job
- scheduled execution uses the OpenClaw default model selected at runtime
- delivery routing is explicit instead of inferred

### Features

- Fetches the latest arXiv `astro-ph/recent` listing
- Scores candidate papers and selects a daily top 3
- Generates structured Chinese summaries using `template.md`
- Supports both manual runs and OpenClaw cron jobs
- Sends staged Weixin notifications when delivery is enabled
- Cleans temporary logs after a successful run

### Directory Layout

```text
astro-arxiv-daily/
├── README.md
├── SKILL.md
├── config.example.sh
├── config.local.sh
├── install-cron.sh
├── template.md
├── references/
│   ├── cron-prompt.md
│   └── openclaw-weixin-delivery.md
├── scripts/
│   ├── run_once.sh
│   ├── fetch_astro_recent.sh
│   ├── build_candidates.py
│   ├── score_candidates.py
│   ├── fetch_paper_artifacts.sh
│   ├── build_top3_context.py
│   ├── extract_paper_notes.py
│   ├── extract_session_text.py
│   └── cleanup_logs.sh
├── logs/
└── output/
```

### Requirements

- OpenClaw installed and available in `PATH`
- A working OpenClaw config at `~/.openclaw/openclaw.json`
- Network access for normal arXiv fetching
- If Weixin delivery is needed:
  - `openclaw-weixin` installed and working
  - a valid Weixin bot account already logged in
  - a correct target user ID confirmed for that account

### Configuration

Copy the example config first:

```bash
cp config.example.sh config.local.sh
```

Important variables:

- `ASTRO_ARXIV_DAILY_CHANNEL`
  Usually `openclaw-weixin`
- `ASTRO_ARXIV_DAILY_ACCOUNT_ID`
  The concrete Weixin bot account used to send messages
- `ASTRO_ARXIV_DAILY_TO`
  The exact inbound target ID observed by the plugin, usually ending with `@im.wechat`
- `ASTRO_ARXIV_DAILY_TZ`
  Time zone used by the cron job
- `ASTRO_ARXIV_DAILY_CRON`
  Cron expression consumed by `install-cron.sh`
- `ASTRO_ARXIV_DAILY_JOB_NAME`
  OpenClaw cron job name
- `ASTRO_ARXIV_DAILY_JOB_DESCRIPTION`
  Human-readable job description

Notes:

- `config.local.sh` is machine-local and should not be committed
- `delivery.to` must exactly match the real inbound `from_user_id` observed by `openclaw-weixin` for the chosen account
- `delivery.channel`, `delivery.accountId`, and `delivery.to` should represent the same route as `ASTRO_ARXIV_DAILY_CHANNEL`, `ASTRO_ARXIV_DAILY_ACCOUNT_ID`, and `ASTRO_ARXIV_DAILY_TO`

See also:

- `references/openclaw-weixin-delivery.md`
- `references/cron-prompt.md`

### Quick Start

#### 1. Configure local variables

```bash
cp config.example.sh config.local.sh
source ./config.local.sh
```

#### 2. Install the OpenClaw cron job

```bash
bash ./install-cron.sh
```

#### 3. Run once manually

```bash
bash ./scripts/run_once.sh
```

By default, a local run only generates files and does not send messages.

### Local Run Modes

#### Generate output only

```bash
bash ./scripts/run_once.sh
```

Expected outputs:

- `output/YYYY-MM-DD-top3.txt`
- `logs/YYYY-MM-DD-scoring.json`
- intermediate files under `logs/`

#### Generate output and send Weixin notifications

```bash
source ./config.local.sh
export ASTRO_ARXIV_DAILY_SEND_WEIXIN=1
bash ./scripts/run_once.sh
```

When delivery is enabled, `run_once.sh` sends:

- a start notification
- a candidate-count notification
- a top-3 arXiv-ID notification
- the final digest body

### Scheduled Run Model

The cron job created by `install-cron.sh`:

- uses an isolated session
- uses light context
- minimizes outer-agent re-interpretation
- jumps directly into `scripts/run_once.sh`
- uses the OpenClaw default model selected at runtime

The scheduled outer prompt is stored in:

- `references/cron-prompt.md`

### Output Format

The final digest is written to:

- `output/YYYY-MM-DD-top3.txt`

Each paper block contains:

- `English Title`
- `Chinese Title`
- `arXiv ID`
- a Chinese analysis body following `template.md`

The final text is extracted from the local one-shot session by:

- `scripts/extract_session_text.py`

### Important Files

- `template.md`
  Controls the final digest structure
- `scripts/run_once.sh`
  Main orchestration script shared by local and cron runs
- `install-cron.sh`
  Creates the OpenClaw cron job
- `config.example.sh`
  Public configuration template
- `references/openclaw-weixin-delivery.md`
  Documents how Weixin delivery values should be mapped

### Troubleshooting

#### Cron shows `running`, but no actual work starts

- Check `openclaw cron list --json`
- Check `~/.openclaw/cron/jobs.json`
- Check `~/.openclaw/agents/main/sessions/`

#### Final output is not created

- Inspect `logs/YYYY-MM-DD-run-once-prompt.md`
- Inspect `logs/YYYY-MM-DD-run-once-response.txt`
- Inspect the matching one-shot session under `~/.openclaw/agents/main/sessions/`

#### Weixin logs show success, but the user does not receive anything

- Confirm the configured `accountId` still exists and is logged in
- Confirm `ASTRO_ARXIV_DAILY_TO` is the real inbound target ID for that account
- Confirm the bot account and the target user are on the same live conversation route

#### Weixin reports `account not configured`

- Re-check `ASTRO_ARXIV_DAILY_ACCOUNT_ID`
- Make sure that account really exists in the local `openclaw-weixin` account store
- Re-run `install-cron.sh` after changing delivery configuration

### Before Publishing To GitHub

Before uploading this directory:

- do not commit `config.local.sh`
- do not commit personal IDs, bot account IDs, or filled delivery targets
- review `logs/` and `output/` and remove local artifacts
- keep `config.example.sh` generic

This repository is intended to publish the workflow and scripts, not your private delivery route.
