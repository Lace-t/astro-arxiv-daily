#!/usr/bin/env bash

# Copy this file to config.local.sh or export these variables in your shell
# before running install-cron.sh.

export ASTRO_ARXIV_DAILY_TO="CHANGE_ME@im.wechat"
export ASTRO_ARXIV_DAILY_ACCOUNT="CHANGE_ME_ACCOUNT_ID"
export ASTRO_ARXIV_DAILY_CHANNEL="openclaw-weixin"
export ASTRO_ARXIV_DAILY_TZ="Asia/Shanghai"
export ASTRO_ARXIV_DAILY_CRON="30 11 * * 1-5"
export ASTRO_ARXIV_DAILY_JOB_NAME="astro-arxiv-daily"
export ASTRO_ARXIV_DAILY_JOB_DESCRIPTION="Weekday astro-ph top-3 digest"
