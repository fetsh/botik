# frozen_string_literal: true

RSpec.describe Botik::Update do
  it "parses hashes and JSON" do
    hash = telegram_message("hi")
    expect(described_class.parse(hash).text).to eq("hi")
    expect(described_class.parse(JSON.generate(hash)).text).to eq("hi")
    expect { described_class.parse(42) }.to raise_error(ArgumentError)
  end

  describe "a message" do
    subject(:update) { described_class.new(telegram_message("/start@shop_bot ref 42", chat: { id: 5 })) }

    it "knows its type, chat and sender" do
      expect(update.type).to eq(:message)
      expect(update.message_type?).to be(true)
      expect(update.chat_id).to eq(5)
      expect(update.user_id).to eq(100)
      expect(update.effective_message).to equal(update.object)
    end

    it "parses the command" do
      expect(update.command).to have_attributes(name: "start", username: "shop_bot", args: "ref 42")
      expect(update.command.argv).to eq(%w[ref 42])
    end

    it "uses the caption as text" do
      update = described_class.new(telegram_message(caption: "photo caption"))
      expect(update.text).to eq("photo caption")
    end
  end

  it "does not treat a command in the middle of text as a command" do
    hash = telegram_message("say /start")
    hash["message"]["entities"] = [{ "type" => "bot_command", "offset" => 4, "length" => 6 }]
    expect(described_class.new(hash).command).to be_nil
  end

  describe "a callback query" do
    subject(:update) { described_class.new(telegram_callback("items/1", from: { id: 7 })) }

    it "exposes data, sender and the message with the button" do
      expect(update.type).to eq(:callback_query)
      expect(update.callback_data).to eq("items/1")
      expect(update.user_id).to eq(7)
      expect(update.chat_id).to eq(100)
      expect(update.effective_message.text).to eq("button message")
      expect(update.text).to be_nil
    end
  end

  it "handles updates without a chat" do
    update = described_class.new(telegram_update(:inline_query, id: "1", query: "cats"))
    expect(update.type).to eq(:inline_query)
    expect(update.chat).to be_nil
    expect(update.from.id).to eq(100)
  end

  it "finds the user of poll answers" do
    update = described_class.new("update_id" => 1, "poll_answer" => { "poll_id" => "p", "user" => { "id" => 9 } })
    expect(update.user_id).to eq(9)
  end
end
