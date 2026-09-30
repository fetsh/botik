# frozen_string_literal: true

RSpec.describe "Two bots in one project" do
  let!(:shop_api) { Botik::Testing.fake_client!(ShopBot) }
  let!(:support_api) { Botik::Testing.fake_client!(SupportBot) }

  it "routes /start of each bot to its own controller" do
    ShopBot.call(telegram_message("/start"))
    SupportBot.call(telegram_message("/start"))

    expect(shop_api.sent_messages.last[:text]).to start_with("<b>Catalog</b>")
    expect(support_api.sent_messages.last[:text]).to eq("Describe your problem")
  end

  it "renders the implicit template with partials, helpers, escaping and a keyboard" do
    ShopBot.call(telegram_message("/start"))

    message = shop_api.sent_messages.last
    expect(message[:parse_mode]).to eq("HTML")
    expect(message[:text]).to eq(<<~TEXT.strip)
      <b>Catalog</b>
      • Tea &lt;green&gt; — 12.50 ₪
      • Coffee_beans* — 40.00 ₪
    TEXT
    expect(message[:reply_markup]).to eq(
      inline_keyboard: [[{ text: "#1", callback_data: "items/1" }], [{ text: "#2", callback_data: "items/2" }]]
    )
  end

  it "edits the message on a callback with a MarkdownV2 template and answers the query" do
    update = telegram_callback("items/2")
    ShopBot.call(update)

    edit = shop_api.calls(:edit_message_text).last.params
    expect(edit).to include(
      chat_id: 100,
      message_id: update["callback_query"]["message"]["message_id"],
      parse_mode: "MarkdownV2",
      text: "*Coffee\\_beans\\**\nPrice: 40\\.00 ₪\n_Thanks\\!_"
    )
    expect(shop_api.calls(:answer_callback_query).size).to eq(1)
  end

  it "keeps conversation state in the session between updates" do
    ShopBot.call(telegram_callback("items/1/buy"))
    expect(shop_api.calls(:answer_callback_query).map { |c| c.params[:text] }).to eq(["Added"])

    ShopBot.call(telegram_message("Herzl 1, Ashdod"))
    expect(shop_api.sent_messages.last[:text]).to eq("Delivering to Herzl 1, Ashdod")

    ShopBot.call(telegram_message("find tea"))
    expect(shop_api.sent_messages.last[:text]).to eq("Searching tea")
  end

  it "does not share sessions between bots" do
    ShopBot.call(telegram_callback("items/1/buy"))
    session_keys = Botik.config.session_store.instance_variable_get(:@data).keys
    expect(session_keys).to eq(["botik:111:100:100"])
  end

  it "resolves namespaced controllers only when the constraint allows" do
    SupportBot.call(telegram_message("/stats", from: { id: 2 }))
    expect(support_api.calls).to be_empty

    SupportBot.call(telegram_message("/stats", from: { id: 1 }))
    expect(support_api.sent_messages.last[:text]).to eq("42 tickets")
  end

  it "uses the default route with a plain-text template" do
    ShopBot.call(telegram_message("hello"))
    expect(shop_api.sent_messages.last).to include(text: "Sorry, I don't understand hello <b>")
    expect(shop_api.sent_messages.last).not_to have_key(:parse_mode)
  end

  it "routes messages by content type" do
    ShopBot.call(telegram_message(photo: [{ file_id: "x", width: 1, height: 1 }]))
    expect(shop_api.sent_messages.last[:text]).to eq("Nice photo")
  end
end
