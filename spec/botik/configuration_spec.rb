# frozen_string_literal: true

RSpec.describe Botik::Configuration do
  it "falls back to the parent and then to defaults" do
    root = described_class.new
    child = described_class.new(root)

    expect(child.api_url).to eq("https://api.telegram.org")
    root.api_url = "http://local"
    expect(child.api_url).to eq("http://local")
    child.api_url = "http://child"
    expect(child.api_url).to eq("http://child")
    expect(root.api_url).to eq("http://local")
  end

  it "memoizes callable defaults without marking them as set" do
    config = described_class.new
    expect(config.session_store).to equal(config.session_store)
    expect(config.set?(:session_store)).to be(false)
    config.logger = Logger.new(nil)
    expect(config.set?(:logger)).to be(true)
    config.unset(:logger)
    expect(config.set?(:logger)).to be(false)
  end
end
