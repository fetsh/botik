# frozen_string_literal: true

require "tmpdir"
require "rails/generators"
require "generators/botik/bot/bot_generator"

RSpec.describe Botik::Generators::BotGenerator do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = dir
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
      example.run
    end
  end

  def generate(*args)
    capture = StringIO.new
    original = $stdout
    $stdout = capture
    described_class.start(args, destination_root: @root)
  ensure
    $stdout = original
  end

  def read(path)
    File.read(File.join(@root, path))
  end

  it "creates the bot, its controllers and views and mounts the webhook" do
    generate("support")

    expect(read("app/bots/support_bot.rb")).to include("class SupportBot < Botik::Bot", 'ENV["SUPPORT_BOT_TOKEN"]',
                                                       'command :start, to: "start#show"')
    expect(read("app/bots/support_bot/application_controller.rb"))
      .to include("class SupportBot::ApplicationController < Botik::Controller")
    expect(read("app/bots/support_bot/start_controller.rb")).to include("def show")
    expect(read("app/views/support_bot/start/show.html.erb")).to include("<%= bold(@name) %>")
    expect(read("app/views/support_bot/start/help.html.erb")).to include("/help")
    expect(read("config/routes.rb")).to include('mount SupportBot.webhook => "/telegram/support"')
  end

  it "does not double the suffix and can skip the route" do
    generate("shop_bot", "--skip-route")

    expect(File).to exist(File.join(@root, "app/bots/shop_bot.rb"))
    expect(read("config/routes.rb")).not_to include("mount")
  end

  it "generates code that works" do
    generate("demo")
    load File.join(@root, "app/bots/demo_bot.rb")
    load File.join(@root, "app/bots/demo_bot/application_controller.rb")
    load File.join(@root, "app/bots/demo_bot/start_controller.rb")
    DemoBot.config.view_paths = [File.join(@root, "app/views")]
    api = Botik::Testing.fake_client!(DemoBot)

    DemoBot.call(telegram_message("/start", from: { first_name: "Ann & Bob" }))
    expect(api.sent_messages.last).to include(text: start_with("Hello, <b>Ann &amp; Bob</b>!"), parse_mode: "HTML")
  ensure
    Object.send(:remove_const, :DemoBot) if defined?(DemoBot)
  end
end
