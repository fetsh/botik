# frozen_string_literal: true

RSpec.describe Botik::Bot do
  it "registers named bots" do
    expect(Botik.bots).to include(ShopBot, SupportBot)
  end

  it "keeps configuration separate per bot and falls back to the global config" do
    expect(ShopBot.config.token).to eq("111:SHOP")
    expect(SupportBot.config.token).to eq("222:SUPPORT")
    expect(ShopBot.config.view_paths).to eq(Botik.config.view_paths)
    expect(ShopBot.bot_id).to eq("111")
    expect(ShopBot.controller_namespace).to eq("ShopBot")
  end

  describe "subclassing a bot (same code, another token)" do
    let(:tenant) { Class.new(ShopBot) { configure { |c| c.token = "333:TENANT" } } }
    let!(:api) { Botik::Testing.fake_client!(tenant) }

    it "inherits routes, controllers and settings but not the token" do
      expect(tenant.routes).to equal(ShopBot.routes)
      expect(tenant.controller_namespace).to eq("ShopBot")
      expect(tenant.config.username).to eq("shop_bot")
      expect(tenant.bot_id).to eq("333")

      tenant.call(telegram_message("find milk"))
      expect(api.sent_messages.last[:text]).to eq("Searching milk")
    end
  end

  it "builds a real client from the configuration and rebuilds it after configure" do
    bot = Class.new(described_class) { configure { |c| c.token = "1:A" } }
    expect(bot.client).to be_a(Botik::Client).and(have_attributes(token: "1:A"))
    bot.configure { |c| c.token = "2:B" }
    expect(bot.client.token).to eq("2:B")
  end

  it "returns nil and sends nothing when no route matches" do
    bot = Class.new(described_class) { configure { |c| c.token = "1:A" } }
    api = Botik::Testing.fake_client!(bot)
    expect(bot.call(telegram_message("hi"))).to be_nil
    expect(api.calls).to be_empty
  end

  it "dispatches to callable endpoints" do
    bot = Class.new(described_class) do
      routes { on :poll, to: ->(request) { "poll #{request.update.object.id}" } }
    end
    expect(bot.call(telegram_update(:poll, id: "p1"))).to eq("poll p1")
  end

  describe "middleware" do
    let(:recorder) do
      Class.new do
        def initialize(app, log, label)
          @app = app
          @log = log
          @label = label
        end

        def call(request)
          @log << "#{@label}>"
          result = @app.call(request)
          @log << "<#{@label}"
          result
        end
      end
    end

    it "wraps processing in order and is inherited by subclasses" do
      log = []
      bot = Class.new(described_class) do
        routes { default to: ->(_request) { log << "endpoint" } }
      end
      bot.use recorder, log, "a"
      bot.use recorder, log, "b"
      child = Class.new(bot)
      child.middleware.delete(recorder)

      bot.call(telegram_message("x"))
      expect(log).to eq(["a>", "b>", "endpoint", "<b", "<a"])

      log.clear
      child.call(telegram_message("x"))
      expect(log).to eq(["endpoint"])
    end

    it "can stop processing" do
      stopper = Class.new do
        def initialize(app) = @app = app
        def call(request) = request.update.from.is_bot ? :ignored : @app.call(request)
      end
      bot = Class.new(described_class) { routes { default to: ->(_request) { :processed } } }
      bot.use stopper

      expect(bot.call(telegram_message("x", from: { is_bot: true }))).to eq(:ignored)
      expect(bot.call(telegram_message("x"))).to eq(:processed)
    end
  end

  it "instruments update processing" do
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("process_update.botik") { |event| events << event }
    Botik::Testing.fake_client!(ShopBot)
    ShopBot.call(telegram_message("/start"))
    expect(events.map { |event| event.payload[:update].type }).to eq([:message])
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  it "sets the webhook with the configured secret" do
    bot = Class.new(described_class) { configure { |c| c.webhook_secret = "s3cret" } }
    api = Botik::Testing.fake_client!(bot)
    bot.set_webhook("https://example.com/hook", drop_pending_updates: true)
    expect(api.last_call.to_h).to eq(api_method: :set_webhook,
                                     params: { url: "https://example.com/hook", secret_token: "s3cret",
                                               drop_pending_updates: true })
  end

  it "reports errors through the error handler" do
    errors = []
    bot = Class.new(described_class) { configure { |c| c.error_handler = ->(e, u) { errors << [e.message, u.id] } } }
    bot.handle_error(RuntimeError.new("boom"), Botik::Update.new("update_id" => 5))
    expect(errors).to eq([["boom", 5]])
  end

  it "saves the session only when processing succeeds" do
    bot = Class.new(described_class) do
      configure { |c| c.token = "5:S" }
      routes do
        text "ok", to: ->(request) { request.session[:seen] = true }
        text "fail", to: ->(request) { request.session[:seen] = true; raise "boom" } # rubocop:disable Style/Semicolon
      end
    end
    store = Botik.config.session_store

    expect { bot.call(telegram_message("fail")) }.to raise_error("boom")
    expect(store.read("botik:5:100:100")).to be_nil
    bot.call(telegram_message("ok"))
    expect(store.read("botik:5:100:100")).to eq("seen" => true)
  end
end
