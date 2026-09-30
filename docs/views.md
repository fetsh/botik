# Views

Templates are ERB files in the bot's view paths (`app/views` in Rails):

```
app/views/<bot>/<controller>/<action>.<format>.erb
app/views/shop_bot/orders/show.html.erb
```

The directory comes from `controller_path`: `ShopBot::Admin::StatsController`
uses `shop_bot/admin/stats`.

## Formats

The format in the file name decides the message's `parse_mode` and how
`<%= %>` output is escaped:

| file | parse_mode | `<%= value %>` escapes |
|---|---|---|
| `show.html.erb` | `HTML` | `&`, `<`, `>`, quotes |
| `show.md.erb` (or `.markdown.erb`) | `MarkdownV2` | `_*[]()~`>#+-=|{}.!\` |
| `show.text.erb` (or `.txt.erb`) | none | nothing |

This means user input can't break your markup:

```erb
<%# orders/show.md.erb %>
*Order \#<%= @order.id %>*
Customer: <%= @order.customer_name %>   <%# "Ann_B." becomes "Ann\_B\." %>
```

Use `<%== value %>` or `raw(value)` to insert markup as is.

Template text outside ERB tags is **not** escaped, so in `.md.erb` templates
you must escape literal special characters yourself (`\#`, `\.`, `\!`). If you
don't need MarkdownV2 features, HTML templates are simpler to write.

The rendered text is stripped of leading and trailing whitespace. Lines that
contain only `<% %>` tags leave no empty lines behind.

## Formatting helpers

These helpers produce markup for the current format and escape their
arguments:

```erb
<%= bold(@user.name) %>  <%= italic("note") %>  <%= underline("u") %>  <%= strike("old") %>
<%= spoiler("secret") %>  <%= code(@order.token) %>  <%= pre(@log, "ruby") %>
<%= link("Open order", order_url(@order)) %>  <%= quote(@message.text) %>
```

In `.text.erb` templates they return the plain text.

## Instance variables and helpers

Controller instance variables are copied to the view, except those starting
with `@_`. The view can also use `params`, `session`, `update`, `chat`, `from`,
`bot` and `controller`, and every helper added with `helper` or
`helper_method` (see [Controllers](controllers.md#view-helpers)).

## Keyboards in views

A view can set the message's reply markup:

```erb
Choose a size:
<% inline_keyboard do |k|
     k.row do
       %w[S M L].each { |size| k.button size, callback: "sizes/#{size}" }
     end
     k.button "Size chart", url: "https://example.com/sizes"
   end %>
```

```erb
<% reply_keyboard(one_time: true, placeholder: "Your phone") do |k|
     k.button "📱 Share phone", request_contact: true
   end %>
<% remove_keyboard %>
<% force_reply(placeholder: "Your name") %>
```

Use the `|k|` block argument in views. The argument-less form changes `self`,
which hides your instance variables and helpers.

The same builder is available in controllers (`inline_keyboard { |k| … }`,
`reply_keyboard`) and anywhere as `Botik::Keyboard.inline`,
`Botik::Keyboard.reply`, `.remove` and `.force_reply`. In an inline keyboard,
`callback:` is short for `callback_data:`. Other Telegram button fields (`url:`,
`web_app:`, `switch_inline_query:`, `pay:`, `request_contact:`,
`request_location:`, …) are passed through as is.

## Partials

```erb
<% @items.each do |item| -%>
<%= render "item", item: item %>
<% end -%>
<%= render "shared/footer" %>
```

- `render "item"` looks up `_item.<format>.erb` next to the controller's views.
- `render "shared/footer"` looks up `app/views/<bot>/shared/_footer`, then
  `app/views/shared/_footer`, so every bot can have its own shared partials.
- `render "/shared/footer"` skips the bot's directory.

Locals become local variables in the partial. A partial prefers the format of
the template that renders it. The trailing newline of a partial is dropped, so
`<%= render "item" %>` on its own line produces exactly one line.

## Rendering without sending

```ruby
rendered = render_to_string(:receipt, locals: { order: @order })
rendered.text           # => "..."
rendered.parse_mode     # => "HTML"
rendered.reply_markup   # => { inline_keyboard: … } or nil

reply_with :photo, photo: @order.qr_code, caption: rendered.text, parse_mode: rendered.parse_mode
```

## Templates are compiled once

Templates are compiled into Ruby methods on first use and recompiled when the
file changes. Changes show up without a restart in development, and in
production each template is compiled only once.
