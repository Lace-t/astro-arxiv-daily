# OpenClaw Weixin Delivery

Fill in your own delivery values before installing a scheduled job.

## Example Values

- `delivery.channel`: `openclaw-weixin`
- `delivery.to`: `CHANGE_ME@im.wechat`
- `delivery.accountId`: `CHANGE_ME_ACCOUNT_ID`
- `timezone`: `Asia/Shanghai`
- `cron`: `30 11 * * 1-5`

## Delivery Block

```yaml
delivery:
  mode: announce
  channel: openclaw-weixin
  to: "CHANGE_ME@im.wechat"
  accountId: "CHANGE_ME_ACCOUNT_ID"
timezone: "Asia/Shanghai"
cron: "30 11 * * 1-5"
```

## Notes

- `delivery.to` must be your explicit Weixin user ID ending with `@im.wechat`.
- `delivery.accountId` must be explicit for reliable scheduled pushes.
- If you are unsure about the account ID, inspect your local OpenClaw Weixin account files under `~/.openclaw/openclaw-weixin/`.
