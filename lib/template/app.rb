require 'botik'
Dir[File.join(File.dirname(__FILE__), 'controllers', '*.rb')].each { |file| require file }
module Template
  class App < Botik::App
    configure do |config|
      config.bot_token = '????????????????????????????????????????????'
    end

    route do |update|
      if update.command_message?
        :command_controller
      elsif update.text_message?
        :text_message_controller
      else
        :application_controller
      end
    end
  end
end
