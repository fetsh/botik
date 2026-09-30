# Upgrading from 0.x

Botik 1.0 is a rewrite. The idea is the same, "a bot structured like a Rails
app", but none of the 0.x API remains.

| 0.x | 1.0 |
|---|---|
| `class App < Botik::App` with `configure` and one `route { \|update\| :controller }` block | `class MyBot < Botik::Bot` with `configure` and a [routing DSL](routing.md) that routes to actions |
| a controller with a single `process` method | controllers with several actions: `to: "orders#show"` |
| `Message`/`EditMessage` classes that build API params | ERB [views](views.md) with auto-escaping; `reply`, `render`, `edit_message` |
| `send_message(MessageClass, opts:)` | `reply "text"`, `render :template`, `api.send_message(...)` |
| `telegram-bot-ruby` with monkey patches | a built-in API client; updates are `Botik::Payload`s |
| one global bot per namespace | any number of bots; configuration inherits |
| `botik new NAME` generator | `rails generate botik:bot NAME` |
| — | sessions, conversation state, webhook Rack app, poller, rake tasks, test helpers |

Migration steps:

1. Change the app class to inherit from `Botik::Bot`.
2. Replace the `route` block with `routes do … end`.
3. Rename `process` to actions and move message classes into templates or
   `reply` calls.
4. Replace `update.command_message?` with `update.command?`,
   `update.text_message` with `update.effective_message`, and
   `update.callback?` with `update.callback_query?`.
