# frozen_string_literal: true

module Botik
  # Everything known about the update being processed: the bot, the update,
  # the matched route with its params, and the session. Middleware, route
  # constraints and controllers all receive it.
  class Request
    attr_reader :bot, :update
    attr_accessor :route, :params

    def initialize(bot, update)
      @bot = bot
      @update = update
      @params = ActiveSupport::HashWithIndifferentAccess.new
    end

    def session
      @session ||= Session.new(bot.config.session_store, session_key)
    end

    def session_loaded?
      !@session.nil? && @session.loaded?
    end

    def logger
      bot.logger
    end

    private

    def session_key
      custom = bot.config.session_key
      return custom.call(update) if custom
      return nil if update.chat_id.nil? && update.user_id.nil?

      ["botik", bot.bot_id, update.chat_id, update.user_id].join(":")
    end
  end
end
