module Botik
  class App
    class << self
      attr_writer :configuration
    end

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield(configuration)
    end

    def self.route(&block)
      @route_proc = block
    end

    def self.bot
      @bot ||= Telegram::Bot::Client.new(configuration.bot_token)
    end

    attr_reader :update

    def initialize(update)
      # Telegram::Bot::Types::Update.new(TheOldReader::App.bot.fetch_updates(&:to_h).first)
      if update.is_a?(Telegram::Bot::Types::Update)
        @update = update
      else
        if update.respond_to?(:body)
          update.body.rewind
          update = update.body.read
        end
        @update = Telegram::Bot::Types::Update.new(MultiJson.load(update))
      end
    end

    def process
      controller_for(update).process(update)
    end

    private

    def controller_for(update)
      controller = self.class.instance_variable_get('@route_proc').call(update)
      "#{self.class.name.deconstantize}::#{controller.to_s.classify}".constantize
    end
  end
end
