# Controllers

A controller is a class inheriting from `Botik::Controller`. It lives in its
bot's namespace, and its public methods are its actions:

```ruby
class ShopBot::OrdersController < ShopBot::ApplicationController
  before_action :load_order, only: %i[show cancel]

  def show
    # renders app/views/shop_bot/orders/show.*.erb unless the action responded
  end

  def cancel
    @order.cancel!
    edit_message "Order ##{@order.id} cancelled"
  end

  private

  def load_order
    @order = current_customer.orders.find(params[:id])
  end
end
```

Give each bot an `ApplicationController` for shared behaviour. Different bots
don't share controllers unless you want them to (see
[Multiple bots](multiple_bots.md)).

## What's available in an action

| | |
|---|---|
| `update` | the `Botik::Update` |
| `params` | route params (`params[:id]`, `params[:args]`, …), a `HashWithIndifferentAccess` |
| `session` | the per-chat [session](sessions.md) |
| `state` / `state=` | the conversation state (see [Sessions](sessions.md)) |
| `chat` | the chat of the update (`chat.id`, `chat.type`) |
| `from` | the user who sent the update (`from.id`, `from.first_name`, `from.language_code`) |
| `effective_message` | the message; for callback queries, the message with the button |
| `callback_query` | the callback query, or nil |
| `api` | the Bot API client: `api.get_chat_member(chat_id: …, user_id: …)` |
| `bot` | the bot class |
| `logger` | the bot's logger |
| `action_name`, `request` | as in Rails |

### Reading updates

Updates and every object inside them are `Botik::Payload`s. A payload exposes
the Telegram JSON fields as methods, returns nil for absent fields and answers
`field?` predicates:

```ruby
update.type                      # => :message, :callback_query, :inline_query, …
update.object                    # the Message / CallbackQuery / InlineQuery …
update.message.photo.last.file_id
update.text                      # text or caption of a message
update.callback_data
update.command                   # => #<data Command name="start", username=nil, args="ref42">
update.chat_id, update.user_id
update.message.reply_to_message? # => true / false
update.object[:from]             # hash-style access works too
update.to_h                      # plain Hash, JSON-serializable
```

## Responding

Every helper below sends to the current chat. It also marks the action as
*performed*: implicit rendering is skipped, and a `before_action` that
responds halts the chain.

```ruby
reply "Hello"                                     # sendMessage
reply "<b>Hi</b>", parse_mode: "HTML", disable_notification: true
reply "Pick one", reply_markup: inline_keyboard { |k| k.button "A", callback: "a" }

render                                            # the action's template
render :summary, locals: { total: 3 }             # another template of this controller
render "shared/help"                              # app/views/<bot>/shared/help, then app/views/shared/help
render plain: "No formatting"
render :show, reply_markup: Botik::Keyboard.remove

reply_with :photo, photo: File.open("chart.png"), caption: "Sales"
reply_with :document, document: "BQACAgIAAx…"    # file_id or URL
reply_with :location, latitude: 31.8, longitude: 34.65

edit_message "Done ✅"                              # the message with the pressed button
edit_message template: :show                       # rendered from a template
edit_message reply_markup: new_keyboard            # without text, only the markup changes
edit_message "Updated", message_id: 123

delete_message                                     # the current message
answer_callback_query "Saved"                      # toast
answer_callback_query "Are you sure?", show_alert: true
answer_inline_query results, cache_time: 0

chat_action :typing                                # doesn't count as a response
```

`responses` returns the API results of these calls, and `performed?` reports
whether there are any. For anything else, call the API directly:

```ruby
api.pin_chat_message(chat_id: chat.id, message_id: responses.last.message_id)
```

### Implicit rendering

When an action finishes without responding and a template for it exists,
Botik renders and sends that template. This mirrors Rails. When no template
exists, nothing is sent, which suits actions that only record something.

### Callback queries are answered automatically

Telegram shows a spinner on a pressed button until the bot answers the
callback query. If an action doesn't call `answer_callback_query`, Botik
answers with an empty answer after the action. You can turn this off with
`config.auto_answer_callback_queries = false`.

## Callbacks

These work the same as in Rails:

```ruby
before_action :require_admin, except: :index
before_action { chat_action :typing }
after_action :track, only: %i[create update]
around_action :with_locale

skip_before_action :require_admin, only: :help    # in a subclass
prepend_before_action :load_user
```

Options are `only:`, `except:`, `if:` and `unless:`. `if:` and `unless:` take a
method name symbol or a proc.

A `before_action` halts the chain if it **responds**:

```ruby
def require_admin
  reply "Admins only" unless current_user.admin?
end
```

To send something without halting, call the API directly
(`api.send_message(chat_id: chat.id, text: …)`).

```ruby
def with_locale(&)
  I18n.with_locale(from&.language_code || I18n.default_locale, &)
end
```

## Handling errors

```ruby
class ShopBot::ApplicationController < Botik::Controller
  rescue_from ActiveRecord::RecordNotFound do
    reply "Not found 🤷"
  end

  rescue_from Botik::ApiError::Forbidden, with: :user_blocked_bot

  private

  def user_blocked_bot
    current_customer.update!(blocked_bot: true)
  end
end
```

Unhandled errors propagate out of `Bot.call`. The webhook and the poller catch
them and pass them to `config.error_handler` (in Rails: `Rails.error.report`).
See [Delivery](delivery.md).

Botik raises these API errors: `Botik::ApiError` and its subclasses
`BadRequest` (400), `Unauthorized` (401), `Forbidden` (403), `NotFound` (404),
`Conflict` (409) and `TooManyRequests` (429, with `retry_after`). Network
failures raise `Botik::NetworkError`.

## View helpers

Controller methods can be exposed to views, and helper modules can be added:

```ruby
class ShopBot::ApplicationController < Botik::Controller
  helper ShopBot::PriceHelper
  helper_method :current_customer

  private

  def current_customer
    @current_customer ||= Customer.find_or_create_by!(telegram_id: from.id)
  end
end
```

Helpers are inherited by subclasses.
