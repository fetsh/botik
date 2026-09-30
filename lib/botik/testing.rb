# frozen_string_literal: true

require "botik"
require_relative "testing/fake_client"
require_relative "testing/updates"

module Botik
  # Test support for applications built with Botik.
  #
  #   require "botik/testing"
  #
  #   RSpec.configure do |config|
  #     config.include Botik::Testing::Helpers
  #   end
  #
  #   it "greets on /start" do
  #     api = Botik::Testing.fake_client!(SupportBot)
  #     SupportBot.call(telegram_message("/start"))
  #     expect(api.sent_messages.last[:text]).to include("Welcome")
  #   end
  module Testing
    # Replaces the bot's API client with a FakeClient and returns it.
    def self.fake_client!(bot)
      bot.client = FakeClient.new
    end

    # Update builders for specs: telegram_message, telegram_callback, telegram_update.
    module Helpers
      def telegram_message(text = nil, **)
        Updates.message(text, **)
      end

      def telegram_callback(data, **)
        Updates.callback_query(data, **)
      end

      def telegram_update(type, object = {}, **)
        Updates.update(type, object, **)
      end
    end
  end
end
