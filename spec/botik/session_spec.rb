# frozen_string_literal: true

RSpec.describe Botik::Session do
  let(:store) { Botik::SessionStore::Memory.new }

  it "loads lazily and writes back only when changed" do
    allow(store).to receive(:write).and_call_original
    session = described_class.new(store, "k")

    session.commit
    expect(session).not_to be_loaded

    session[:step] = "email"
    session.commit
    expect(store.read("k")).to eq("step" => "email")

    session.commit
    expect(store).to have_received(:write).once
  end

  it "stringifies keys" do
    session = described_class.new(store, "k")
    session[:a] = 1
    expect(session["a"]).to eq(1)
    expect(session.key?(:a)).to be(true)
    expect(session.fetch(:b, 2)).to eq(2)
  end

  it "deletes the stored entry when emptied" do
    store.write("k", { "a" => 1 })
    session = described_class.new(store, "k")
    session.clear
    session.commit
    expect(store.read("k")).to be_nil
  end

  it "notices nested changes" do
    store.write("k", { "cart" => [1] })
    session = described_class.new(store, "k")
    session[:cart] << 2
    session.commit
    expect(store.read("k")).to eq("cart" => [1, 2])
  end

  it "is not persisted without a key" do
    session = described_class.new(store, nil)
    session[:a] = 1
    expect { session.commit }.not_to raise_error
  end

  describe Botik::SessionStore::Memory do
    it "returns copies and expires entries" do
      store = described_class.new(expires_in: 0)
      value = { "a" => [1] }
      store.write("k", value)
      value["a"] << 2
      expect(store.read("k")).to be_nil

      store = described_class.new
      store.write("k", value)
      store.read("k")["a"] << 3
      expect(store.read("k")).to eq("a" => [1, 2])
      expect(store.delete("k")).to be(true)
    end
  end
end
