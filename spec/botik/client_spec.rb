# frozen_string_literal: true

RSpec.describe Botik::Client do
  subject(:client) { described_class.new("123:ABC") }

  let(:base) { "https://api.telegram.org/bot123:ABC" }

  it "requires a token" do
    expect { described_class.new(nil) }.to raise_error(Botik::ConfigurationError)
  end

  it "calls snake_case methods as camelCase API methods with a JSON body" do
    stub = stub_request(:post, "#{base}/sendMessage")
           .with(body: { chat_id: 1, text: "Hi", reply_markup: { inline_keyboard: [] } }.to_json,
                 headers: { "Content-Type" => "application/json" })
           .to_return(body: { ok: true, result: { message_id: 5 } }.to_json)

    result = client.send_message(chat_id: 1, text: "Hi", parse_mode: nil, reply_markup: { inline_keyboard: [] })

    expect(stub).to have_been_requested
    expect(result.message_id).to eq(5)
  end

  it "accepts the explicit form" do
    stub_request(:post, "#{base}/getMe").to_return(body: { ok: true, result: { username: "b" } }.to_json)
    expect(client.call("getMe").username).to eq("b")
  end

  it "uploads files as multipart" do
    stub = stub_request(:post, "#{base}/sendPhoto").with do |request|
      request.headers["Content-Type"].start_with?("multipart/form-data") &&
        request.body.include?('filename="spec_helper.rb"') &&
        request.body.include?('{"inline_keyboard":[]}')
    end.to_return(body: { ok: true, result: true }.to_json)

    File.open(File.expand_path("../spec_helper.rb", __dir__)) do |file|
      client.send_photo(chat_id: 1, photo: file, reply_markup: { inline_keyboard: [] })
    end
    expect(stub).to have_been_requested
  end

  it "raises specific API errors" do
    stub_request(:post, "#{base}/sendMessage").to_return(
      status: 429, body: { ok: false, error_code: 429, description: "Too Many Requests",
                           parameters: { retry_after: 7 } }.to_json
    )

    expect { client.send_message(chat_id: 1, text: "x") }.to raise_error(Botik::ApiError::TooManyRequests) { |error|
      expect(error.retry_after).to eq(7)
      expect(error.api_method).to eq("sendMessage")
      expect(error.message).to eq("sendMessage failed (429): Too Many Requests")
    }
  end

  it "maps 403 to Forbidden" do
    stub_request(:post, "#{base}/sendMessage")
      .to_return(status: 403, body: { ok: false, error_code: 403, description: "bot was blocked" }.to_json)
    expect { client.send_message(chat_id: 1, text: "x") }.to raise_error(Botik::ApiError::Forbidden)
  end

  it "wraps network failures and garbage responses in NetworkError" do
    stub_request(:post, "#{base}/getMe").to_timeout
    expect { client.get_me }.to raise_error(Botik::NetworkError, /getMe/)

    stub_request(:post, "#{base}/getMe").to_return(status: 502, body: "<html>Bad gateway</html>")
    expect { client.get_me }.to raise_error(Botik::NetworkError, /502/)
  end

  it "instruments API calls" do
    stub_request(:post, "#{base}/getMe").to_return(body: { ok: true, result: {} }.to_json)
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("api_call.botik") { |event| events << event }
    client.get_me
    expect(events.map { |event| event.payload[:api_method] }).to eq(["getMe"])
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
