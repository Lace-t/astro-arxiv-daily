# OpenClaw Target Delivery

Fill in your own delivery values before installing a scheduled job.

## Example Values

- `delivery.channel`: `openclaw-weixin`
- `delivery.accountId`: `CHANGE_ME_ACCOUNT_ID`
- `delivery.to`: `CHANGE_ME@im.wechat`
- `timezone`: `Asia/Shanghai`
- `cron`: `30 11 * * 1-5`

## Delivery Block

```yaml
delivery:
  channel: openclaw-weixin
  accountId: "CHANGE_ME_ACCOUNT_ID"
  mode: announce
  to: "CHANGE_ME@im.wechat"
timezone: "Asia/Shanghai"
cron: "30 11 * * 1-5"
```

## Notes

- `delivery.channel` should stay `openclaw-weixin` for this skill.
- `delivery.accountId` must be the concrete Weixin bot account that has an active session with the target user.
- `delivery.to` must be your explicit target user ID ending with `@im.wechat`.
- `delivery.to` must be the exact inbound `from_user_id` observed by `openclaw-weixin` for that account.
- In this skill, `delivery.channel`, `delivery.accountId`, and `delivery.to` should represent the same route as `ASTRO_ARXIV_DAILY_CHANNEL`, `ASTRO_ARXIV_DAILY_ACCOUNT_ID`, and `ASTRO_ARXIV_DAILY_TO` in `config.local.sh`.

  
