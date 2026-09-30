# frozen_string_literal: true

module Botik
  # Long polling with getUpdates — handy in development and for bots that
  # can't receive webhooks.
  #
  #   SupportBot.poll                              # blocks; Ctrl-C to stop
  #   SupportBot.poll(allowed_updates: %w[message callback_query])
  #
  # Telegram refuses getUpdates while a webhook is set; call
  # <tt>SupportBot.delete_webhook</tt> first (or pass +delete_webhook: true+).
  class Poller
    attr_reader :bot, :offset

    # +timeout+: long polling timeout in seconds; +limit+: updates per request;
    # +allowed_updates+: update types to receive; +delete_webhook+: remove the
    # webhook before polling; +handle_signals+: stop gracefully on INT/TERM.
    def initialize(bot, timeout: 30, limit: 100, allowed_updates: nil, delete_webhook: false,
                   handle_signals: true, sleeper: Kernel)
      @bot = bot
      @timeout = timeout
      @limit = limit
      @allowed_updates = allowed_updates
      @delete_webhook = delete_webhook
      @handle_signals = handle_signals
      @sleeper = sleeper
      @offset = nil
      @running = false
    end

    def run
      @running = true
      bot.delete_webhook if @delete_webhook
      previous_traps = trap_signals if @handle_signals
      bot.logger.info("[botik] #{bot.name || bot} polling for updates")

      poll_once while @running
    ensure
      @running = false
      previous_traps&.each { |signal, handler| Signal.trap(signal, handler || "DEFAULT") }
    end

    def stop
      @running = false
    end

    def running?
      @running
    end

    # Fetches one batch of updates and processes them. Returns the number of updates.
    def poll_once
      updates = fetch
      updates.each do |payload|
        @offset = payload["update_id"] + 1
        process(payload)
      end
      updates.size
    rescue ApiError::TooManyRequests => e
      backoff(e.retry_after || 5, e)
    rescue ApiError::Conflict => e
      bot.logger.error("[botik] #{e.description}. Is a webhook set or another poller running?")
      raise
    rescue NetworkError, ApiError => e
      backoff(3, e)
    end

    private

    def fetch
      params = { offset: @offset, timeout: @timeout, limit: @limit, allowed_updates: @allowed_updates }
      Array(bot.client.get_updates(**params.compact)).map { |update| update.respond_to?(:to_h) ? update.to_h : update }
    end

    def process(payload)
      bot.call(payload)
    rescue StandardError => e
      bot.handle_error(e, Update.new(payload))
    end

    def backoff(seconds, error)
      bot.logger.warn("[botik] #{error.message}; retrying in #{seconds}s")
      @sleeper.sleep(seconds)
      0
    end

    def trap_signals
      %w[INT TERM].to_h do |signal|
        [signal, Signal.trap(signal) { stop }]
      end
    end
  end
end
