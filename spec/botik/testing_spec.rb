# frozen_string_literal: true

RSpec.describe Botik::Testing::FakeClient do
  subject(:api) { described_class.new }

  it "records calls and returns realistic defaults" do
    message = api.send_message(chat_id: 5, text: "hi", parse_mode: nil)
    expect(message.message_id).to eq(1)
    expect(message.chat.id).to eq(5)
    expect(api.get_me.username).to eq("test_bot")
    expect(api.call("answerCallbackQuery", callback_query_id: "1")).to be(true)
    expect(api.calls.map(&:api_method)).to eq(%i[send_message get_me answer_callback_query])
    expect(api.sent_messages).to eq([{ chat_id: 5, text: "hi" }])
  end

  it "supports stubs" do
    api.stub(:get_chat, { "id" => 1, "title" => "Group" })
    api.stub(:send_message) { |params| { "message_id" => 99, "text" => params[:text].upcase } }

    expect(api.get_chat(chat_id: 1).title).to eq("Group")
    expect(api.send_message(chat_id: 1, text: "hi").text).to eq("HI")
    expect(api.reset!.calls).to be_empty
  end
end
