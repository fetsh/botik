# frozen_string_literal: true

RSpec.describe Botik::Payload do
  subject(:payload) do
    described_class.new("chat" => { "id" => 1, "type" => "private" }, "text" => "hi", "photo" => [{ "file_id" => "a" }])
  end

  it "exposes fields as methods, recursively" do
    expect(payload.chat.id).to eq(1)
    expect(payload.text).to eq("hi")
    expect(payload.photo.first.file_id).to eq("a")
  end

  it "returns nil for absent fields and answers predicates" do
    expect(payload.caption).to be_nil
    expect(payload.text?).to be(true)
    expect(payload.caption?).to be(false)
  end

  it "supports hash-style access with strings and symbols" do
    expect(payload[:text]).to eq("hi")
    expect(payload["chat"][:type]).to eq("private")
    expect(payload.dig(:chat, :id)).to eq(1)
    expect(payload.key?(:photo)).to be(true)
  end

  it "converts back to a plain hash and JSON" do
    expect(payload.to_h).to eq("chat" => { "id" => 1, "type" => "private" }, "text" => "hi",
                               "photo" => [{ "file_id" => "a" }])
    expect(JSON.parse(payload.to_json)["text"]).to eq("hi")
  end

  it "does not pretend to be a String or an Array" do
    expect(payload).not_to respond_to(:to_str)
    expect(payload).not_to respond_to(:to_ary)
    expect(Array(payload)).to eq([payload])
  end

  it "compares by content" do
    expect(payload).to eq(described_class.new(payload.to_h))
    expect(payload).to eq(payload.to_h)
  end
end
