# Botik

Build Telegram bots the way you build Rails apps.

```ruby
class ShopBot < Botik::Bot
  configure do |config|
    config.token = ENV.fetch("SHOP_BOT_TOKEN")
  end

  routes do
    command :start, to: "catalog#index"
    callback "items/:id", to: "catalog#show"
    text(/\Afind (?<query>.+)/i, to: "catalog#search")
    default to: "catalog#help"
  end
end

class ShopBot::CatalogController < ShopBot::ApplicationController
  before_action :load_customer

  def index
    @items = Item.featured          # renders app/views/shop_bot/catalog/index.html.erb
  end

  def show
    @item = Item.find(params[:id])
    edit_message template: :show   # edits the message with the pressed button
  end

  def search
    reply "Looking for #{params[:query]}…"
  end
end
```

```erb
<%# app/views/shop_bot/catalog/index.html.erb %>
<b>Today in the shop</b>
<% @items.each do |item| -%>
• <%= item.title %> — <%= item.price %>
<% end -%>
<% inline_keyboard do |k|
     @items.each { |item| k.button item.title, callback: "items/#{item.id}" }
   end %>
```

## Features

- **Routes.** Match updates by command, callback data pattern (`"orders/:id"`), text or regexp, message kind (`:photo`), update type (`:inline_query`), with `scope`/`namespace` blocks and constraints (`chat_type:`, `state:`, `if:`).
- **Controllers.** `before_action`/`after_action`/`around_action` with `only:`/`except:`, `rescue_from`, `params`, `session`, helpers `reply`, `render`, `edit_message`, `answer_callback_query`, `reply_with :photo`…
- **Views.** ERB templates in `app/views/<bot>/<controller>/<action>.{html,md,text}.erb`. The file format sets `parse_mode`, and `<%= %>` output is escaped for HTML or MarkdownV2. Templates can use partials, formatting helpers (`bold`, `link`, `code`…), keyboards and your own helpers. An action that sends nothing renders its template automatically.
- **Several bots per project.** Each bot is a class with its own token, routes, controllers, views and sessions. A bot can also be subclassed to run the same code under another token.
- **Conversation state.** Per-chat sessions in any store (`Rails.cache` works). `self.state = :awaiting_email` plus `scope state: :awaiting_email` routes give you multi-step dialogs.
- **Delivery.** A Rack webhook endpoint with secret-token check (mount it in Rails routes). Long polling with graceful shutdown. Optional background processing through ActiveJob or anything else.
- **Rails integration.** A generator, rake tasks (`botik:routes`, `botik:poll`, `botik:webhook:set`), `Rails.logger`, `Rails.error` reporting and autoloading from `app/bots`. Botik also works without Rails.
- **Testing.** `Botik::Testing::FakeClient` records API calls. Update builders cover messages, callbacks and any other update type.
- **Small footprint.** Botik depends only on `activesupport` and `erubi`. It has its own Bot API client on top of `net/http`, so any API method is available as `client.method_name(**params)`.

## Installation

Botik requires Ruby 3.3+. It is not published on rubygems.org yet, so install it from GitHub:

```ruby
# Gemfile
gem "botik", github: "fetsh/botik"
```

## Quick start with Rails

```sh
bin/rails generate botik:bot support
```

This creates:

```
app/bots/support_bot.rb                         # SupportBot: config + routes
app/bots/support_bot/application_controller.rb  # SupportBot::ApplicationController
app/bots/support_bot/start_controller.rb        # SupportBot::StartController
app/views/support_bot/start/show.html.erb
app/views/support_bot/start/help.html.erb
config/routes.rb                                # mount SupportBot.webhook => "/telegram/support"
```

Set `SUPPORT_BOT_TOKEN` (from [@BotFather](https://t.me/BotFather)) and run the bot with long polling:

```sh
bin/rails botik:poll BOT=SupportBot
```

In production, register the webhook once:

```sh
SUPPORT_BOT_WEBHOOK_SECRET=... bin/rails botik:webhook:set BOT=SupportBot URL=https://example.com/telegram/support
```

## Quick start without Rails

```ruby
# bot.rb
require "botik"

class EchoBot < Botik::Bot
  configure do |config|
    config.token = ENV.fetch("ECHO_BOT_TOKEN")
    config.view_paths = [File.expand_path("views", __dir__)]
  end

  routes do
    command :start, to: "echo#start"
    text to: "echo#echo"
  end
end

class EchoBot::EchoController < Botik::Controller
  def start
    reply "Send me anything"
  end

  def echo
    reply update.text
  end
end

EchoBot.poll
```

To serve webhooks instead, put `run EchoBot.webhook` in `config.ru`.

## How it works

```
Telegram ──▶ webhook (Rack) / poller
               │
               ▼
         EchoBot.call(update)
               │  middleware (optional)
               ▼
         router ── first matching route ──▶ EchoBot::EchoController#action
                                               │ before/around/after actions, rescue_from
                                               │ reply / render / edit_message …
                                               ▼
                                         Bot API client ──▶ Telegram
         session saved
```

## Documentation

| Guide | |
|---|---|
| [Getting started](docs/getting_started.md) | project layout, the first bot, running it |
| [Routing](docs/routing.md) | the routing DSL, params, constraints, namespaces |
| [Controllers](docs/controllers.md) | actions, callbacks, responding, errors, helpers |
| [Views](docs/views.md) | templates, formats and escaping, partials, keyboards |
| [Sessions and state](docs/sessions.md) | sessions, stores, multi-step conversations |
| [Delivery](docs/delivery.md) | webhooks, long polling, background jobs, rake tasks |
| [Multiple bots](docs/multiple_bots.md) | several bots in one app, one codebase with many tokens |
| [Configuration](docs/configuration.md) | every option, the API client, errors, middleware, instrumentation |
| [Testing](docs/testing.md) | testing your bots with the fake client |
| [Upgrading from 0.x](docs/upgrading.md) | what changed in 1.0 |

## Development

```sh
bin/setup       # or: bundle install
bundle exec rake    # specs + rubocop
bin/console
```

Releases are published to GitHub only for now: `bundle exec rake release` builds the gem and tags and pushes the version, but it skips the push to rubygems.org.

## License

MIT, see [LICENSE.txt](LICENSE.txt).
