# Sessions and conversation state

## Sessions

`session` is a small hash that persists between updates. By default each
(bot, chat, user) triple has its own session:

```ruby
def add_to_cart
  session[:cart] ||= []
  session[:cart] << params[:id]
end
```

- Keys are strings; symbols are converted (`session[:cart]` and `session["cart"]` are the same key).
- The session is loaded only when first used. After processing, it is written
  back if it changed and deleted if it became empty.
- The session is saved only if processing **succeeded**. When an exception
  escapes, changes are discarded, much like a database transaction.
- Store simple values (strings, numbers, booleans, arrays, hashes) so any
  store can serialize them. Keep records in your database and put only their
  ids in the session.

`session` supports `[]`, `[]=`, `fetch`, `key?`, `delete`, `update(hash)`,
`clear`, `empty?` and `to_h`.

## Stores

A store is any object with `read(key)`, `write(key, value)` and `delete(key)`.

| store | when |
|---|---|
| `Botik::SessionStore::Memory.new(expires_in: 1.day)` | the default; for development, tests and single-process bots. Data is lost on restart. |
| `Rails.cache` or any `ActiveSupport::Cache::Store` | production: Redis, Memcached, Solid Cache… |
| your own object | e.g. a database table |

```ruby
Botik.configure do |config|
  config.session_store = Rails.cache     # all bots
end

class ShopBot < Botik::Bot
  configure do |config|
    config.session_store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV["REDIS_URL"], expires_in: 30.days)
  end
end
```

## Session keys

The default key is `"botik:<bot id>:<chat id>:<user id>"`. The bot id is the
numeric part of the token, so bots never share sessions, even with the same
store and even when one class runs under several tokens.

To change what the session belongs to, set `session_key`. For example, one
session per group chat, shared by all its members:

```ruby
config.session_key = ->(update) { "shop:chat:#{update.chat_id}" }
```

Updates without a chat or user, such as `poll`, get a session that is never
saved.

## Multi-step conversations with `state`

A controller can set a conversation state, and routes can match on it. This
is how you ask a question and handle the answer in a dedicated action:

```ruby
class ShopBot < Botik::Bot
  routes do
    command :cancel, to: "checkout#cancel"          # works in every state

    scope state: :awaiting_address do
      text to: "checkout#address"
      default to: "checkout#address_expected"
    end
    scope state: :awaiting_phone do
      message :contact, to: "checkout#phone"
      default to: "checkout#phone_expected"
    end

    callback "checkout", to: "checkout#start"
    # ...
  end
end

class ShopBot::CheckoutController < ShopBot::ApplicationController
  def start
    self.state = :awaiting_address
    reply "Where should we deliver?"
  end

  def address
    session[:address] = update.text
    self.state = :awaiting_phone
    reply "Your phone?", reply_markup: reply_keyboard(one_time: true) { |k|
      k.button "📱 Share", request_contact: true
    }
  end

  def phone
    Order.create!(address: session.delete(:address), phone: update.message.contact.phone_number)
    self.state = nil
    reply "Thanks! 🎉", reply_markup: Botik::Keyboard.remove
  end

  def cancel
    self.state = nil
    reply "Cancelled"
  end

  def address_expected = reply("Please send the address as text, or /cancel")
  def phone_expected = reply("Tap “Share” below, or /cancel")
end
```

`self.state = :x` stores `"x"` in `session[:state]`, and `state` reads it back
as a symbol. `self.state = nil` clears it. A `state:` route constraint accepts
a symbol, a string or an array of them.
