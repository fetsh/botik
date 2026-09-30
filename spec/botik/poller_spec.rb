# frozen_string_literal: true

RSpec.describe Botik::Poller do
  let(:processed) { [] }
  let(:bot) do
    log = processed
    Class.new(Botik::Bot) do
      routes { default to: ->(request) { log << request.update.text } }
    end
  end
  let!(:api) { Botik::Testing.fake_client!(bot) }
  let(:sleeper) { class_double(Kernel, sleep: nil) }
  let(:poller) { described_class.new(bot, timeout: 5, sleeper: sleeper, handle_signals: false) }

  it "processes updates and advances the offset" do
    batches = [[telegram_message("a", update_id: 10), telegram_message("b", update_id: 11)], []]
    api.stub(:get_updates) { batches.shift }

    expect(poller.poll_once).to eq(2)
    expect(processed).to eq(%w[a b])
    expect(poller.offset).to eq(12)

    poller.poll_once
    expect(api.calls(:get_updates).map(&:params)).to eq([{ timeout: 5, limit: 100 },
                                                         { offset: 12, timeout: 5, limit: 100 }])
  end

  it "keeps going when an update fails" do
    errors = []
    bot.config.error_handler = ->(error, _update) { errors << error.message }
    bot.routes.clear.draw { default to: ->(request) { raise "bad #{request.update.text}" } }
    api.stub(:get_updates, [telegram_message("x", update_id: 1)])

    poller.poll_once
    expect(errors).to eq(["bad x"])
    expect(poller.offset).to eq(2)
  end

  it "backs off on rate limits and network errors" do
    api.stub(:get_updates) do
      raise Botik::ApiError::TooManyRequests.new(api_method: "getUpdates", error_code: 429,
                                                 description: "slow down", parameters: { "retry_after" => 9 })
    end
    expect(poller.poll_once).to eq(0)
    expect(sleeper).to have_received(:sleep).with(9)

    api.stub(:get_updates) { raise Botik::NetworkError, "timeout" }
    poller.poll_once
    expect(sleeper).to have_received(:sleep).with(3)
  end

  it "fails on conflicts (a webhook is set)" do
    api.stub(:get_updates) do
      raise Botik::ApiError::Conflict.new(api_method: "getUpdates", error_code: 409, description: "webhook is active")
    end
    expect { poller.poll_once }.to raise_error(Botik::ApiError::Conflict)
  end

  it "runs until stopped and can delete the webhook first" do
    poller = described_class.new(bot, delete_webhook: true, sleeper: sleeper, handle_signals: false)
    api.stub(:get_updates) do
      poller.stop
      [telegram_message("last", update_id: 1)]
    end

    poller.run
    expect(api.calls.map(&:api_method)).to eq(%i[delete_webhook get_updates])
    expect(processed).to eq(["last"])
    expect(poller).not_to be_running
  end
end
