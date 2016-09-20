require 'botik/version'
require 'active_support/core_ext/string/inflections'
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

    attr_reader :update

    def initialize(update)
      @update = update
    end

    def process
      controller_for(update).process(update)
    end

    private

    def controller_for(update)
      controller = self.class.instance_variable_get('@route_proc').call(update)
      controller.constantize
    end
  end

  class Configuration
    attr_accessor :bot_token
  end
end



class TheOldReader < Botik::App
  configure do |config|
    config.bot_token = '290297777:AAG5eWyqaTWpkuLTtEVuBbJzRMImuzwVc4s'
  end

  route do |update|
    if update.command_message?
      'CommandController'
    elsif update.text_message?
      'TextMessageController'
    else
      'ApplicationController'
    end
  end
end


TheOldReader.new(update).process
