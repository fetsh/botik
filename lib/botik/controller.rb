module Botik
  class Controller
    include ActiveSupport::Callbacks
    include ActiveSupport::Rescuable

    define_callbacks :process

    def self.process(update)
      new(update).send(:call)
    end

    attr_reader :update

    def initialize(update)
      @update = update
    end

    def process
      puts '- Processing'
    end

    private

    def bot
      "#{self.class.name.deconstantize}::App".constantize.bot
    end

    def call
      run_callbacks :process do
        process
      end
    rescue Exception => exception
      rescue_with_handler(exception) || raise(exception)
    end
  end
end
