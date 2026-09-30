# Routing

Routes are declared in the bot class and map updates to `"controller#action"`:

```ruby
class ShopBot < Botik::Bot
  routes do
    command :start, to: "welcome#start"
    callback "items/:id", to: "items#show"
    default to: "welcome#help"
  end
end
```

Routes are checked **in order**; the first match wins. Put specific routes
before general ones (`text "Menu"` before `text`, commands before `text`).

`to: "items#show"` resolves to `ShopBot::ItemsController#show` when the update
is dispatched. Because of this late lookup, code reloading works. An update
that no route matches is logged at debug level and ignored.

## Matchers

### `command`

```ruby
command :start, to: "welcome#start"
command %i[help h], to: "help#show"     # several names
```

This matches a message that begins with a bot command. The match is
case-insensitive, and `/start@my_bot` also matches. If `config.username` is set,
commands addressed to *another* bot, such as `/start@other_bot` in a group, are
ignored.

Params: `params[:command]` (`"start"`) and `params[:args]`, the rest of the text
(`"/start ref42"` → `"ref42"`). `update.command.argv` splits the arguments.

### `callback`

Matches callback queries (inline keyboard button presses) by `callback_data`:

```ruby
callback "items/:id", to: "items#show"               # "items/42" → params[:id] = "42"
callback "items/:id/buy", to: "items#buy"
callback "vote::choice", to: "votes#create"          # "vote:yes" → params[:choice] = "yes"
callback "files/*path", to: "files#show"             # "files/a/b" → params[:path] = "a/b"
callback(/\Apage-(?<n>\d+)\z/, to: "pages#show")     # named captures become params
callback to: "callbacks#unknown"                      # any callback query
```

Segments (`:name`) match up to the next `/` or `:`. Keep in mind that Telegram
limits `callback_data` to 64 bytes. `params[:data]` always holds the raw data.

### `text`

```ruby
text "Menu", to: "menu#show"                         # exact match
text(/\Afind (?<query>.+)\z/i, to: "search#create")  # params[:query]
text to: "notes#create"                              # any text
```

`text` also matches captions of media messages. For a regexp,
`params[:match]` holds the `MatchData`.

### `message`

```ruby
message :photo, :video, to: "media#create"           # params[:kind] => :photo
message :location, to: "places#nearby"
message to: "messages#other"                         # any message
```

The kind is any field of the
[Message](https://core.telegram.org/bots/api#message) object, for example
`:contact`, `:document`, `:voice`, `:sticker`, `:successful_payment`,
`:new_chat_members` or `:web_app_data`.

### `on`

Matches any update type:

```ruby
on :inline_query, to: "search#inline"
on :my_chat_member, to: "membership#changed"
on :pre_checkout_query, to: "payments#pre_checkout"
on :poll_answer, :poll, to: "polls#update"
```

### `default`

Matches everything; put it last.

```ruby
default to: "welcome#help"
```

### Which updates count as messages

`command`, `text` and `message` match `message`, `channel_post` and
`business_message` updates. Edited messages are **not** matched by default,
because an edited `/pay` shouldn't pay twice. Use `types:` to change this:

```ruby
text to: "notes#update", types: [:edited_message]
command :stats, to: "stats#show", types: %i[message edited_message]
```

## Constraints

Any route, `scope` or `namespace` accepts these options:

| option | matches when |
|---|---|
| `chat_type: :private` | the chat type is one of the given types (`:private`, `:group`, `:supergroup`, `:channel`) |
| `state: :awaiting_email` | `session[:state]` equals the given value (see [Sessions](sessions.md)) |
| `if: ->(request) { … }` | the callable returns true |
| `unless: ->(request) { … }` | the callable returns false |

The callable receives a `Botik::Request` with `request.update`, `request.bot`
and `request.session`.

```ruby
command :stats, to: "stats#show", if: ->(request) { ADMINS.include?(request.update.user_id) }
```

## `scope` and `namespace`

`scope` applies constraints to a group of routes:

```ruby
scope chat_type: :private do
  command :settings, to: "settings#show"

  scope state: :awaiting_email do
    text to: "signup#email"
    default to: "signup#email_expected"
  end
end
```

`namespace` also prefixes controller names:

```ruby
namespace :admin, if: ->(request) { request.update.user_id.in?(ADMINS) } do
  command :stats, to: "stats#show"        # ShopBot::Admin::StatsController#show
  namespace :reports do
    command :daily, to: "daily#show"      # ShopBot::Admin::Reports::DailyController#show
  end
end
```

In nested scopes, inner `chat_type:` and `state:` replace outer ones. Inner
`if:` conditions are combined with outer ones using AND, and inner `unless:`
conditions using OR.

## Callable endpoints

For trivial handlers, `to:` accepts anything that responds to `call`:

```ruby
on :my_chat_member, to: ->(request) { Rails.logger.info(request.update.object.new_chat_member.status) }
```

## Inspecting routes

```ruby
puts ShopBot.routes
# command  /start                   => welcome#start
# callback "items/:id"              => items#show
# text     (any text)               => notes#create state: awaiting_note
```

or `bin/rails botik:routes`.

Routes can be drawn in several `routes do … end` blocks; they are appended in
order. A bot subclass without its own `routes` uses its parent's.
