# frozen_string_literal: true

require "logger"

module Botik
  # Settings of a bot. Every bot has its own Configuration whose unset options fall
  # back to its parent: the superclass bot's configuration, and finally the global
  # Botik.config. That is how shared defaults (logger, session store, view paths)
  # are set once while tokens and usernames stay per bot:
  #
  #   Botik.configure do |config|
  #     config.session_store = Rails.cache
  #   end
  #
  #   class SupportBot < Botik::Bot
  #     configure do |config|
  #       config.token = ENV.fetch("SUPPORT_BOT_TOKEN")
  #       config.username = "acme_support_bot"
  #     end
  #   end
  class Configuration
    OPTIONS = {
      # Bot API token from @BotFather.
      token: nil,
      # The bot's username (without "@"). Commands addressed to another bot
      # ("/start@other_bot") are ignored when it is set.
      username: nil,
      api_url: Client::DEFAULT_API_URL,
      # Read timeout for API calls, seconds.
      timeout: 30,
      open_timeout: 10,
      # Secret sent by Telegram in X-Telegram-Bot-Api-Secret-Token; the webhook
      # rejects requests without it when set.
      webhook_secret: nil,
      # Where ERB views are looked up.
      view_paths: -> { [File.expand_path("app/views")] },
      # Any object with read/write/delete (Botik::SessionStore::Memory, Rails.cache, ...).
      session_store: -> { SessionStore::Memory.new },
      # Callable (update) => key. Default: one session per chat and user.
      session_key: nil,
      logger: -> { Logger.new($stdout, progname: "botik") },
      # Module that holds the bot's controllers. Defaults to the bot class itself.
      controller_namespace: nil,
      # Answer callback queries automatically when an action didn't, so the
      # button stops spinning.
      auto_answer_callback_queries: true,
      # Callable (bot, payload) used by the webhook instead of processing the
      # update inline, e.g. to enqueue a background job.
      async_handler: nil,
      # Callable (exception, update) invoked when the webhook or the poller fails
      # to process an update. Defaults to logging the error.
      error_handler: nil,
      # Replaces the HTTP client, e.g. Botik::Testing::FakeClient in tests.
      client: nil
    }.freeze

    attr_reader :parent

    def initialize(parent = nil)
      @parent = parent
      @values = {}
      @defaults = {}
    end

    OPTIONS.each do |name, default|
      define_method(name) do
        return @values[name] if @values.key?(name)
        return parent.public_send(name) if parent

        @defaults.fetch(name) { @defaults[name] = default.respond_to?(:call) ? default.call : default }
      end

      define_method(:"#{name}=") { |value| @values[name] = value }
    end

    # Whether the option was set on this configuration (not inherited or defaulted).
    def set?(name)
      @values.key?(name.to_sym)
    end

    def unset(name)
      @values.delete(name.to_sym)
    end
  end
end
