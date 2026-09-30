# frozen_string_literal: true

require "rack/mock"

RSpec.describe Botik::Webhook do
  let(:bot) do
    Class.new(Botik::Bot) do
      configure { |c| c.webhook_secret = "s3cret" }
      routes { default to: ->(request) { request.bot.client.send_message(chat_id: 1, text: request.update.text) } }
    end
  end
  let!(:api) { Botik::Testing.fake_client!(bot) }
  let(:app) { described_class.new(bot) }

  def post(body, secret: "s3cret")
    headers = { method: "POST", input: body }
    headers["HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN"] = secret if secret
    Rack::MockRequest.new(app).request("POST", "/", headers)
  end

  it "processes updates" do
    response = post(JSON.generate(telegram_message("hi")))
    expect(response.status).to eq(200)
    expect(api.sent_messages).to eq([{ chat_id: 1, text: "hi" }])
  end

  it "rejects requests without the secret" do
    expect(post("{}", secret: nil).status).to eq(403)
    expect(post("{}", secret: "wrong").status).to eq(403)
    expect(api.calls).to be_empty
  end

  it "rejects bad input and methods" do
    expect(post("not json").status).to eq(400)
    expect(post("[1]").status).to eq(400)
    expect(Rack::MockRequest.new(app).get("/").status).to eq(405)
  end

  it "accepts everything when no secret is configured" do
    bot.config.webhook_secret = nil
    expect(post(JSON.generate(telegram_message("hi")), secret: nil).status).to eq(200)
  end

  it "reports processing errors and still answers 200" do
    errors = []
    bot.config.error_handler = ->(error, update) { errors << [error.message, update.id] }
    api.stub(:send_message) { raise "boom" }
    update = telegram_message("hi")

    expect(post(JSON.generate(update)).status).to eq(200)
    expect(errors).to eq([["boom", update["update_id"]]])
  end

  it "hands updates to the async handler" do
    queued = []
    bot.config.async_handler = ->(target, payload) { queued << [target, payload] }
    update = telegram_message("hi")

    post(JSON.generate(update))
    expect(queued).to eq([[bot, update]])
    expect(api.calls).to be_empty
  end

  it "looks up named bots on each request" do
    Botik::Testing.fake_client!(ShopBot)
    expect(ShopBot.webhook.bot).to equal(ShopBot)
  end
end
