# Testing

```ruby
# spec/rails_helper.rb or spec/spec_helper.rb
require "botik/testing"

RSpec.configure do |config|
  config.include Botik::Testing::Helpers
end
```

## Faking the API

`Botik::Testing.fake_client!(bot)` replaces the bot's API client with a
`Botik::Testing::FakeClient`. The fake records every call instead of talking to
Telegram:

```ruby
RSpec.describe ShopBot do
  let!(:api) { Botik::Testing.fake_client!(ShopBot) }

  it "shows the catalog on /start" do
    ShopBot.call(telegram_message("/start"))

    message = api.sent_messages.last
    expect(message[:text]).to include("Today in the shop")
    expect(message[:reply_markup][:inline_keyboard].flatten.map { _1[:callback_data] }).to include("items/1")
  end

  it "shows an item when its button is pressed" do
    ShopBot.call(telegram_callback("items/1"))

    expect(api.calls(:edit_message_text).last.params[:text]).to include("Green tea")
    expect(api.calls(:answer_callback_query)).to be_present
  end

  it "walks through checkout" do
    ShopBot.call(telegram_callback("checkout"))
    ShopBot.call(telegram_message("Herzl 1, Ashdod"))
    ShopBot.call(telegram_message(contact: { phone_number: "+972500000000", first_name: "Ann" }))

    expect(Order.last).to have_attributes(address: "Herzl 1, Ashdod")
  end
end
```

`FakeClient` provides:

| | |
|---|---|
| `calls` / `calls(:send_message)` | recorded calls (`api_method`, `params`) |
| `sent_messages` | params of all `sendMessage` calls |
| `last_call` | the last call |
| `stub(:get_chat, { "id" => 1, … })` | a fixed result |
| `stub(:send_message) { \|params\| raise Botik::ApiError::Forbidden.new(…) }` | a computed result or an error |
| `reset!` | forget calls and stubs |

Without stubs, `send*` and `edit_message_*` methods return a message with an
increasing `message_id`, `get_me` returns a bot, `get_updates` returns `[]`,
and everything else returns `true`.

You can also plug the fake in through configuration:
`config.client = Botik::Testing::FakeClient.new`.

## Building updates

```ruby
telegram_message("/start ref42")                         # adds the bot_command entity
telegram_message("hi", chat: { id: -100123, type: "supergroup" }, from: { id: 7, language_code: "he" })
telegram_message(photo: [{ file_id: "x", width: 90, height: 90 }], caption: "look")
telegram_message("edited", type: :edited_message)
telegram_callback("items/1", from: { id: 7 })
telegram_callback("x", message: { chat: { id: 5 } })
telegram_update(:inline_query, id: "1", query: "tea", offset: "")
telegram_update(:my_chat_member, chat: { id: 1, type: "private" }, new_chat_member: { status: "kicked" })
```

The defaults are a private chat and a user, both with id 100. The builders
return plain hashes, so you can change them before dispatching.

These builders are also available as `Botik::Testing::Updates.message`,
`.callback_query` and `.update`.

## Testing controllers in isolation

```ruby
request = Botik::Request.new(ShopBot, Botik::Update.parse(telegram_message("hi")))
controller = ShopBot::CatalogController.dispatch(:search, request)
expect(controller.responses.last.text).to eq("Searching hi")
```

## Sessions between examples

The default memory store lives as long as the process, so clear it between
examples:

```ruby
config.before { Botik.config.session_store.clear }
```
