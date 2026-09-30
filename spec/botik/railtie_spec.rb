# frozen_string_literal: true

require "open3"

RSpec.describe "Rails integration" do
  # Boots a minimal Rails app in a separate process so the global
  # configuration of this test process stays untouched.
  def run_in_rails(code)
    app = File.expand_path("../fixtures/rails_app/config/application.rb", __dir__)
    script = <<~RUBY
      require #{app.inspect}
      require "botik/testing"
      #{code}
    RUBY
    output, status = Open3.capture2e("ruby", "-I", File.expand_path("../../lib", __dir__), "-e", script)
    raise "Rails process failed:\n#{output}" unless status.success?

    output
  end

  it "uses Rails defaults and autoloads bots from app/bots" do
    output = run_in_rails(<<~RUBY)
      puts Botik.config.logger.equal?(Rails.logger)
      puts Botik.config.view_paths.inspect
      api = Botik::Testing.fake_client!(EchoBot)
      EchoBot.call(Botik::Testing::Updates.message("ping"))
      puts api.sent_messages.last[:text]
    RUBY

    expect(output.lines.map(&:chomp)).to eq(
      ["true", [File.expand_path("../fixtures/rails_app/app/views", __dir__)].inspect, "ping"]
    )
  end

  it "reports webhook errors through Rails.error" do
    output = run_in_rails(<<~RUBY)
      class Subscriber
        def report(error, **) = puts("reported \#{error.message}")
      end
      Rails.error.subscribe(Subscriber.new)
      EchoBot.config.client = Object.new.tap { |o| def o.send_message(**) = raise("boom") }
      EchoBot.client = nil
      env = { "REQUEST_METHOD" => "POST", "rack.input" => StringIO.new(JSON.generate(Botik::Testing::Updates.message("x"))) }
      puts EchoBot.webhook.call(env).first
    RUBY

    expect(output.lines.map(&:chomp)).to eq(["reported boom", "200"])
  end

  it "provides rake tasks" do
    output = run_in_rails(<<~RUBY)
      require "rake"
      Rails.application.load_tasks
      Rake::Task["botik:routes"].invoke
    RUBY

    expect(output).to include("EchoBot:", "text     (any text)               => echo#say")
  end
end
