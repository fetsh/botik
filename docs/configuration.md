# Configuration

Each bot has a `config`. Any option a bot doesn't set falls back, in order, to:

1. the parent bot's config (for bot subclasses);
2. the global `Botik.config`;
3. the built-in default.

```ruby
# global defaults
Botik.configure do |config|
  config.logger = Logger.new($stdout)
end

# per bot
class ShopBot < Botik::Bot
  configure do |config|
    config.token = ENV.fetch("SHOP_BOT_TOKEN")
  end
end

ShopBot.config.token
ShopBot.config.set?(:logger)   # => false (inherited)
```

| option | default | |
|---|---|---|
| `token` | — | Bot API token from @BotFather. Required to call the API. |
| `username` | nil | The bot's username without `@`. When set, commands addressed to other bots (`/start@other_bot`) are ignored. |
| `webhook_secret` | nil | Secret token for webhooks; see [Delivery](delivery.md#secret-token). |
| `view_paths` | `["./app/views"]` (Rails: `Rails.root/app/views`) | Directories with templates. |
| `session_store` | `Botik::SessionStore::Memory.new` | See [Sessions](sessions.md#stores). |
| `session_key` | per bot, chat and user | `->(update) { "key" }` |
| `logger` | `Logger.new($stdout)` (Rails: `Rails.logger`) | |
| `controller_namespace` | the bot class name | Module that holds the controllers. |
| `auto_answer_callback_queries` | true | Answer unanswered callback queries after the action. |
| `async_handler` | nil | `->(bot, payload) { … }` called by the webhook instead of processing inline. |
| `error_handler` | log (Rails: log + `Rails.error.report`) | `->(exception, update) { … }` for errors in the webhook and the poller. |
| `api_url` | `https://api.telegram.org` | Point it at a [local Bot API server](https://github.com/tdlib/telegram-bot-api). |
| `timeout` / `open_timeout` | 30 / 10 | HTTP timeouts in seconds. |
| `client` | nil | Replaces the API client object (e.g. a fake in tests). |

`configure` also resets the memoized API client, so a changed token takes
effect.

## The API client

`ShopBot.client` (alias `ShopBot.api`, or `api` in controllers) calls any Bot
API method. Method names are snake_case, and parameters are keywords:

```ruby
api = ShopBot.client
api.get_me.username
api.send_message(chat_id: 1, text: "Hi", reply_markup: Botik::Keyboard.inline { |k| k.button "Go", url: "https://x.y" })
api.send_document(chat_id: 1, document: File.open("report.pdf"))       # multipart upload
api.set_my_commands(commands: [{ command: "start", description: "Start" }])
api.call("sendMessage", chat_id: 1, text: "explicit form")
```

- nil parameters are dropped.
- Hashes and arrays are JSON-encoded.
- Anything that responds to `read`, such as a `File` or `StringIO`, is uploaded
  as multipart/form-data.
- Results are wrapped in `Botik::Payload`.

Because every method goes through the same generic call, new Bot API methods
work without a Botik update.

Errors:

```ruby
begin
  api.send_message(chat_id: user.telegram_id, text: "News")
rescue Botik::ApiError::Forbidden
  user.update!(blocked_bot: true)          # the user blocked the bot
rescue Botik::ApiError::TooManyRequests => e
  sleep e.retry_after
  retry
rescue Botik::ApiError => e
  Rails.logger.warn("#{e.error_code} #{e.description}")
rescue Botik::NetworkError
  # timeouts, connection errors, invalid responses
end
```

`Botik::Client.new(token, api_url:, timeout:, open_timeout:)` can be used on
its own, without a bot.

## Middleware

Middleware wraps the processing of every update, just like Rack middleware.
It receives a `Botik::Request` (`update`, `bot`, `session`, and later `route`
and `params`):

```ruby
class DropStaleUpdates
  def initialize(app, max_age: 60)
    @app = app
    @max_age = max_age
  end

  def call(request)
    date = request.update.effective_message&.date
    return if date && Time.now.to_i - date > @max_age

    @app.call(request)
  end
end

class ShopBot < Botik::Bot
  use DropStaleUpdates, max_age: 120
end

ShopBot.middleware.insert_before(DropStaleUpdates, SomethingElse)
ShopBot.middleware.delete(DropStaleUpdates)
```

A bot subclass copies its parent's middleware stack the first time the stack
is accessed.

## Instrumentation

Botik publishes `ActiveSupport::Notifications` events:

| event | payload |
|---|---|
| `process_update.botik` | `bot`, `update` |
| `api_call.botik` | `api_method`, `params` |

```ruby
ActiveSupport::Notifications.subscribe("process_update.botik") do |event|
  Rails.logger.info("#{event.payload[:bot].name} #{event.payload[:update].type} in #{event.duration.round(1)}ms")
end
```
