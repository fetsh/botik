# Multiple bots

## Several bots in one app

Each bot is a separate `Botik::Bot` subclass. Nothing is global, so each bot
has its own:

- token, username, webhook secret and every other [setting](configuration.md);
- routes;
- controllers (`ShopBot::…Controller`, `SupportBot::…Controller`);
- views (`app/views/shop_bot/…`, `app/views/support_bot/…`), including `shared/` partials;
- sessions (keys include the bot id);
- middleware;
- API client.

```
app/bots/shop_bot.rb
app/bots/shop_bot/application_controller.rb
app/bots/shop_bot/catalog_controller.rb
app/bots/support_bot.rb
app/bots/support_bot/application_controller.rb
app/bots/support_bot/tickets_controller.rb
app/views/shop_bot/...
app/views/support_bot/...
```

```ruby
# config/routes.rb
mount ShopBot.webhook => "/telegram/shop"
mount SupportBot.webhook => "/telegram/support"
```

Shared defaults go into the global configuration. Each bot falls back to it
for every option it doesn't set:

```ruby
# config/initializers/botik.rb
Botik.configure do |config|
  config.session_store = Rails.cache
  config.async_handler = ->(bot, payload) { TelegramUpdateJob.perform_later(bot.name, payload) }
end
```

### Sharing code between bots

Share behaviour through ordinary Ruby: a common base controller or concerns.

```ruby
# app/bots/concerns/telegram_user.rb
module TelegramUser
  extend ActiveSupport::Concern

  included do
    before_action :load_user
    helper_method :current_user
  end

  private

  def load_user
    @current_user = User.find_or_create_by!(telegram_id: from.id)
  end

  def current_user = @current_user
end

class ShopBot::ApplicationController < Botik::Controller
  include TelegramUser
end
```

Rails treats `app/bots/concerns` as an autoload root, the same way it treats
`app/models/concerns`, so this file defines `TelegramUser`, not
`Concerns::TelegramUser`.

A bot can also use controllers from another namespace:

```ruby
class ShopBot < Botik::Bot
  configure { |c| c.controller_namespace = "Storefront" }   # Storefront::CatalogController
end
```

To send a message from one bot to another bot's user, call that bot's client
directly: `SupportBot.client.send_message(chat_id: …, text: …)`.

## One codebase, many tokens

When the same bot runs under many tokens (a white-label bot, one bot per
customer), subclass it. The subclass inherits routes, controllers, views and
settings, and overrides only what differs:

```ruby
class TenantBot < Botik::Bot
  routes do
    command :start, to: "welcome#start"            # TenantBot::WelcomeController
  end
end

def TenantBot.for(tenant)
  @bots ||= {}
  @bots[tenant.id] ||= Class.new(self) do
    configure do |config|
      config.token = tenant.telegram_token
      config.webhook_secret = tenant.webhook_secret
    end
  end
end

# config/routes.rb: one webhook URL per tenant
post "/telegram/tenants/:tenant_id", to: lambda { |env|
  tenant = Tenant.find(env["action_dispatch.request.path_parameters"][:tenant_id])
  TenantBot.for(tenant).webhook.call(env)
}
```

Sessions are separated by the bot id, which is taken from the token. In
controllers, `bot` returns the tenant's subclass, so `bot.config` holds that
tenant's settings.
