# frozen_string_literal: true

module Botik
  # Rack endpoint for Telegram webhooks. Mount it in Rails:
  #
  #   # config/routes.rb
  #   mount SupportBot.webhook => "/telegram/support"
  #
  # or run it with any Rack server (<tt>run SupportBot.webhook</tt> in config.ru).
  #
  # When the bot has a +webhook_secret+, requests without the matching
  # X-Telegram-Bot-Api-Secret-Token header are rejected with 403.
  #
  # Updates are processed inline unless +config.async_handler+ is set. Errors are
  # reported through the bot's error handler and answered with 200 anyway:
  # otherwise Telegram would redeliver the failing update over and over,
  # blocking every update after it.
  class Webhook
    HEADERS = { "content-type" => "application/json" }.freeze

    def initialize(bot)
      # Named bots are looked up on every request so code reloading works.
      @bot_name = bot.name
      @bot = bot unless @bot_name
    end

    def bot
      @bot || @bot_name.constantize
    end

    def call(env)
      return response(405) unless env["REQUEST_METHOD"] == "POST"

      bot = self.bot
      return response(403) unless authorized?(bot, env)

      payload = parse(env)
      return response(400) unless payload

      process(bot, payload)
      response(200)
    end

    def inspect
      "#<#{self.class.name} #{bot.name || bot}>"
    end

    private

    def authorized?(bot, env)
      secret = bot.config.webhook_secret
      return true if secret.nil? || secret.empty?

      ActiveSupport::SecurityUtils.secure_compare(env["HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN"].to_s, secret)
    end

    def parse(env)
      input = env["rack.input"]
      return nil unless input

      input.rewind if input.respond_to?(:rewind)
      payload = JSON.parse(input.read)
      payload.is_a?(Hash) ? payload : nil
    rescue JSON::ParserError
      nil
    end

    def process(bot, payload)
      if bot.config.async_handler
        bot.config.async_handler.call(bot, payload)
      else
        bot.call(payload)
      end
    rescue StandardError => e
      bot.handle_error(e, Update.new(payload))
    end

    def response(status)
      [status, HEADERS.dup, [status == 200 ? "{}" : %({"ok":false})]]
    end
  end
end
