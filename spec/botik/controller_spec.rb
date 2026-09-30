# frozen_string_literal: true

module TestBot
  class GreetingsController < Botik::Controller
    class Blocked < StandardError; end

    before_action { log << :before_all }
    before_action :guard, only: :guarded
    after_action(except: :hello) { log << :after }
    around_action :wrap, only: :plain

    rescue_from Blocked, with: :blocked

    helper_method :current_user_name

    def hello
      @name = "<Ann>"
    end

    def card
      @name = "Ann_B"
    end

    def formats
      @name = "Bo"
    end

    def plain
      log << :action
      render plain: "plain"
    end

    def guarded
      log << :should_not_run
    end

    def explicit
      render "shared/help"
    end

    def global
      render "/shared/help"
    end

    def nothing; end

    def missing
      render :nope
    end

    def failing
      raise Blocked
    end

    def unhandled
      raise ArgumentError, "boom"
    end

    def edit
      edit_message "Edited", reply_markup: inline_keyboard { |k| k.button "x", callback: "x" }
    end

    def edit_markup
      edit_message reply_markup: Botik::Keyboard.inline { |k| k.button "y", callback: "y" }
    end

    def answer
      answer_callback_query "Done", show_alert: true
    end

    def photo
      reply_with :photo, photo: "file-id", caption: "cap"
      reply "and text"
    end

    def remember
      self.state = :waiting
      session[:counter] = session.fetch(:counter, 0) + 1
    end

    def forget
      self.state = nil
    end

    def log
      @_log ||= []
    end

    private

    def current_user_name
      "(#{from.first_name})"
    end

    def guard
      reply "Access denied"
    end

    def wrap
      log << :around_before
      yield
      log << :around_after
    end

    def blocked
      reply "handled"
    end
  end
end

RSpec.describe Botik::Controller do
  let(:bot) do
    Class.new(Botik::Bot) do
      configure do |config|
        config.token = "999:TEST"
        config.controller_namespace = "TestBot"
      end
    end
  end
  let!(:api) { Botik::Testing.fake_client!(bot) }

  def run(action, update = telegram_message("hi"))
    request = Botik::Request.new(bot, Botik::Update.parse(update))
    TestBot::GreetingsController.dispatch(action, request).tap { request.session.commit }
  end

  describe "rendering" do
    it "renders the action's template implicitly with escaping and helper methods" do
      run(:hello)
      expect(api.sent_messages).to eq([{ chat_id: 100, text: "Hi, &lt;Ann&gt;! (Test)", parse_mode: "HTML" }])
    end

    it "escapes MarkdownV2 and sets the keyboard from the view" do
      run(:card)
      message = api.sent_messages.last
      expect(message[:parse_mode]).to eq("MarkdownV2")
      expect(message[:text]).to eq(
        "*Ann\\_B* _1\\.5_ `a\\`b` [site \\(new\\)](https://x.y/(z\\))\nAnn\\_B *raw*"
      )
      expect(message[:reply_markup]).to eq(keyboard: [[{ text: "Ok" }]], resize_keyboard: true,
                                           one_time_keyboard: true)
    end

    it "supports HTML formatting helpers and global partials with locals" do
      run(:formats)
      expect(api.sent_messages.last[:text]).to eq(
        %(<b>Bo</b> <pre><code class="language-ruby">x &lt; y</code></pre> ) +
        %(<a href="https://x.y/?a=1&amp;b=2">a&amp;b</a> <i>ok</i>\n— Botik)
      )
    end

    it "looks up path templates in the bot's directory first" do
      run(:explicit)
      expect(api.sent_messages.last).to eq(chat_id: 100, text: "Bot-specific help for")
    end

    it "sends nothing when there is no template and no response" do
      controller = run(:nothing)
      expect(api.calls).to be_empty
      expect(controller).not_to be_performed
    end

    it "looks up templates from the view root with a leading slash" do
      run(:global)
      expect(api.sent_messages.last[:text]).to eq("Global help")
    end

    it "raises for a missing explicit template" do
      expect { run(:missing) }.to raise_error(Botik::TemplateMissing, %r{test_bot/greetings/nope})
    end

    it "renders to string without sending" do
      request = Botik::Request.new(bot, Botik::Update.parse(telegram_message("hi")))
      controller = TestBot::GreetingsController.new(request)
      controller.instance_variable_set(:@name, "X")
      rendered = controller.render_to_string(:hello)
      expect(rendered.text).to eq("Hi, X! (Test)")
      expect(api.calls).to be_empty
    end
  end

  describe "callbacks" do
    it "runs before, around and after actions" do
      controller = run(:plain)
      expect(controller.log).to eq(%i[before_all around_before action around_after after])
      expect(api.sent_messages.last[:text]).to eq("plain")
    end

    it "halts when a before_action responds" do
      controller = run(:guarded)
      expect(controller.log).to eq([:before_all])
      expect(api.sent_messages.map { |m| m[:text] }).to eq(["Access denied"])
    end

    it "supports skip_before_action in subclasses" do
      subclass = Class.new(TestBot::GreetingsController) do
        def self.name = "TestBot::GreetingsController"
        skip_before_action :guard
      end
      request = Botik::Request.new(bot, Botik::Update.parse(telegram_message("hi")))
      expect(subclass.dispatch(:guarded, request).log).to eq(%i[before_all should_not_run after])
    end
  end

  describe "errors" do
    it "handles errors with rescue_from" do
      run(:failing)
      expect(api.sent_messages.last[:text]).to eq("handled")
    end

    it "re-raises unhandled errors" do
      expect { run(:unhandled) }.to raise_error(ArgumentError, "boom")
    end

    it "refuses non-actions" do
      expect { run(:guard) }.to raise_error(Botik::ActionNotFound)
      expect { run(:render) }.to raise_error(Botik::ActionNotFound)
    end
  end

  describe "messaging" do
    it "edits the callback's message text and markup" do
      update = telegram_callback("x")
      run(:edit, update)
      expect(api.calls(:edit_message_text).last.params).to eq(
        chat_id: 100, message_id: update["callback_query"]["message"]["message_id"], text: "Edited",
        reply_markup: { inline_keyboard: [[{ text: "x", callback_data: "x" }]] }
      )
      expect(api.calls(:answer_callback_query).size).to eq(1)
    end

    it "edits only the markup without text" do
      run(:edit_markup, telegram_callback("x"))
      expect(api.calls.map(&:api_method)).to eq(%i[edit_message_reply_markup answer_callback_query])
    end

    it "edits inline messages by inline_message_id" do
      update = telegram_callback("x", inline_message_id: "im1")
      update["callback_query"].delete("message")
      run(:edit, update)
      expect(api.calls(:edit_message_text).last.params).to include(inline_message_id: "im1")
    end

    it "does not auto-answer an answered callback query" do
      run(:answer, telegram_callback("x"))
      expect(api.calls(:answer_callback_query).map(&:params)).to match([hash_including(text: "Done", show_alert: true)])
    end

    it "does not auto-answer when disabled" do
      bot.config.auto_answer_callback_queries = false
      run(:nothing, telegram_callback("x"))
      expect(api.calls).to be_empty
    end

    it "sends other message kinds" do
      controller = run(:photo)
      expect(api.calls.map(&:api_method)).to eq(%i[send_photo send_message])
      expect(api.calls.first.params).to eq(chat_id: 100, photo: "file-id", caption: "cap")
      expect(controller.responses.map(&:message_id)).to eq([1, 2])
    end
  end

  describe "state and session" do
    it "stores state and data in the session" do
      run(:remember)
      controller = run(:remember)
      expect(controller.state).to eq(:waiting)
      expect(controller.session[:counter]).to eq(2)

      expect(run(:forget).session.key?(:state)).to be(false)
    end
  end

  it "exposes names and paths" do
    expect(TestBot::GreetingsController.controller_path).to eq("test_bot/greetings")
    expect(TestBot::GreetingsController.controller_name).to eq("greetings")
    expect(TestBot::GreetingsController.action_methods).to include("hello", "log")
    expect(TestBot::GreetingsController.action_methods).not_to include("guard", "reply", "state")
  end
end
