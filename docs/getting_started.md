# Getting started

## Project layout

Botik follows Rails conventions. Every bot is a class whose name is also the
namespace of its controllers and the directory of its views:

```
app/
  bots/
    support_bot.rb                     # class SupportBot < Botik::Bot
    support_bot/
      application_controller.rb        # SupportBot::ApplicationController
      tickets_controller.rb            # SupportBot::TicketsController
      admin/
        stats_controller.rb            # SupportBot::Admin::StatsController
  views/
    support_bot/
      tickets/
        new.html.erb
        show.md.erb
      shared/
        _footer.html.erb
```

In Rails, `app/bots` is autoloaded like any other `app/*` directory, and code
reloading works in development. Without Rails, require the files yourself or
set up Zeitwerk.

## The bot class

```ruby
class SupportBot < Botik::Bot
  configure do |config|
    config.token = ENV.fetch("SUPPORT_BOT_TOKEN")
    config.username = "acme_support_bot"   # optional, see Routing › commands
    config.webhook_secret = ENV["SUPPORT_BOT_WEBHOOK_SECRET"]
  end

  routes do
    command :start, to: "tickets#new"
    text to: "tickets#create"
  end
end
```

`SupportBot` gives you:

| | |
|---|---|
| `SupportBot.call(update)` | process one update (a Hash, JSON string or `Botik::Update`) |
| `SupportBot.webhook` | a Rack app for Telegram webhooks |
| `SupportBot.poll` | long polling, blocks until stopped |
| `SupportBot.client` / `.api` | the Bot API client: `SupportBot.client.get_me` |
| `SupportBot.routes` | the route set; `puts SupportBot.routes` prints it |
| `SupportBot.config` | the configuration |
| `SupportBot.use(Middleware)` | adds update middleware |

## Controllers

```ruby
class SupportBot::ApplicationController < Botik::Controller
end

class SupportBot::TicketsController < SupportBot::ApplicationController
  def new
    # no reply: app/views/support_bot/tickets/new.*.erb is rendered and sent
  end

  def create
    ticket = Ticket.create!(telegram_id: from.id, body: update.text)
    reply "Ticket ##{ticket.id} created. We'll get back to you soon."
  end
end
```

## Views

```erb
<%# app/views/support_bot/tickets/new.html.erb %>
Hi <%= from.first_name %>! Describe your problem in <b>one message</b>.
```

## Running

In development, use long polling:

```sh
bin/rails botik:poll BOT=SupportBot
# or, without Rails:
ruby -r ./bot.rb -e 'SupportBot.poll'
```

In production, mount the webhook and register it:

```ruby
# config/routes.rb
mount SupportBot.webhook => "/telegram/support"
```

```sh
bin/rails botik:webhook:set BOT=SupportBot URL=https://example.com/telegram/support
```

Next: [Routing](routing.md).
