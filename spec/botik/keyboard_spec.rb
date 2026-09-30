# frozen_string_literal: true

RSpec.describe Botik::Keyboard do
  it "builds inline keyboards with rows and standalone buttons" do
    markup = described_class.inline do |k|
      k.row do
        k.button "Yes", callback: "yes"
        k.button "No", callback: "no"
      end
      k.button "Site", url: "https://example.com"
    end

    expect(markup).to eq(inline_keyboard: [
                           [{ text: "Yes", callback_data: "yes" }, { text: "No", callback_data: "no" }],
                           [{ text: "Site", url: "https://example.com" }]
                         ])
  end

  it "supports the argument-less block style" do
    markup = described_class.inline { row { button "A", callback: "a" } }
    expect(markup).to eq(inline_keyboard: [[{ text: "A", callback_data: "a" }]])
  end

  it "requires an action for inline buttons" do
    expect { described_class.inline { |k| k.button "Oops" } }.to raise_error(ArgumentError, /Oops/)
  end

  it "does not allow nested rows" do
    expect { described_class.inline { |k| k.row { k.row { nil } } } }.to raise_error(ArgumentError)
  end

  it "builds reply keyboards and special markups" do
    markup = described_class.reply(one_time: true, placeholder: "Choose") do |k|
      k.button "Share phone", request_contact: true
    end
    expect(markup).to eq(
      keyboard: [[{ text: "Share phone", request_contact: true }]],
      resize_keyboard: true, one_time_keyboard: true, input_field_placeholder: "Choose"
    )
    expect(described_class.remove).to eq(remove_keyboard: true)
    expect(described_class.force_reply(placeholder: "Name")).to eq(force_reply: true, input_field_placeholder: "Name")
  end
end
