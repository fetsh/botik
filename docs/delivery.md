# Delivery: webhooks and long polling

Telegram delivers updates in one of two ways. With a **webhook**, Telegram
POSTs every update to your URL; use this in production. With **long
polling**, your process asks Telegram for updates (`getUpdates`); use this in
development and behind firewalls. A bot can't use both at once.

## Webhooks

`SupportBot.webhook` is a Rack application.

```ruby
# Rails: config/routes.rb
mount SupportBot.webhook => "/telegram/support"
mount ShopBot.webhook => "/telegram/shop"
```

```ruby
# Plain Rack: config.ru
require_relative "bot"
run SupportBot.webhook
```

Register the URL once (and again whenever it changes):

```sh
bin/rails botik:webhook:set BOT=SupportBot URL=https://example.com/telegram/support
bin/rails botik:webhook:info BOT=SupportBot
bin/rails botik:webhook:delete BOT=SupportBot
```

You can also do this from Ruby: `SupportBot.set_webhook(url, drop_pending_updates: true, allowed_updates: %w[message callback_query])`.

### Secret token

Set `config.webhook_secret` (1–256 characters: `A-Z`, `a-z`, `0-9`, `_`,
`-`). `set_webhook` passes it to Telegram, and Telegram sends it back in the
`X-Telegram-Bot-Api-Secret-Token` header. The webhook rejects requests without
a matching header (403), so nobody else can feed updates to your bot. Always
set it in production.

### Responses and errors

The webhook answers:

- 200 for a processed update;
- 403 for a wrong secret;
- 400 for a body that isn't JSON;
- 405 for a request that isn't POST.

If processing raises, the error goes to `config.error_handler`, and the
response is **still 200**. Otherwise Telegram would retry the failing update
again and again and hold back all the updates after it. In Rails, the default
handler logs the error and calls `Rails.error.report`, so it reaches your
error tracker.

```ruby
config.error_handler = ->(error, update) { Sentry.capture_exception(error, extra: { update: update&.to_h }) }
```

### Processing in the background

By default, updates are processed inside the webhook request, and Telegram
waits for the response. For slow actions, enqueue the update and respond
immediately:

```ruby
# app/jobs/telegram_update_job.rb
class TelegramUpdateJob < ApplicationJob
  queue_as :telegram

  def perform(bot_name, payload)
    bot_name.constantize.call(payload)
  end
end

# config/initializers/botik.rb
Botik.configure do |config|
  config.async_handler = ->(bot, payload) { TelegramUpdateJob.perform_later(bot.name, payload) }
end
```

`payload` is the update as a plain JSON-compatible Hash. Keep in mind that
parallel workers can process two updates from the same chat out of order.

## Long polling

```ruby
SupportBot.poll                                        # blocks; Ctrl-C / SIGTERM stop it gracefully
SupportBot.poll(allowed_updates: %w[message callback_query], timeout: 50)
SupportBot.poll(delete_webhook: true)                  # remove a webhook first
```

```sh
bin/rails botik:poll BOT=SupportBot
bin/rails botik:poll BOT=SupportBot DELETE_WEBHOOK=1
```

The poller acknowledges each update (by advancing the offset) whether or not
processing succeeded. Errors go to `config.error_handler`. On network errors,
the poller retries after 3 seconds; on rate limits, after `retry_after`. If a
webhook is set, `getUpdates` fails with 409 Conflict and the poller stops with
an error that explains why.

For custom loops, use `SupportBot.poller(...)` and call `poll_once` or
`run`/`stop` yourself.

## Rake tasks

Rails loads these tasks automatically. Without Rails, add
`load "botik/tasks.rake"` to your Rakefile and define an `:environment` task
that loads your bots.

| task | |
|---|---|
| `botik:routes` | print the routes of every bot (or `BOT=`) |
| `botik:poll BOT=X` | long polling (`DELETE_WEBHOOK=1` to remove the webhook first) |
| `botik:webhook:set BOT=X URL=…` | register the webhook (`DROP_PENDING=1` to drop queued updates) |
| `botik:webhook:delete BOT=X` | remove the webhook |
| `botik:webhook:info BOT=X` | show `getWebhookInfo` |

`BOT` can be omitted when the app has only one bot.

## Running a poller as a service

```ini
# /etc/systemd/system/support-bot.service
[Service]
WorkingDirectory=/srv/app
ExecStart=/usr/bin/env bin/rails botik:poll BOT=SupportBot
Restart=always
Environment=RAILS_ENV=production
```
