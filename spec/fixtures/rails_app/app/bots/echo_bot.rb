# frozen_string_literal: true

class EchoBot < Botik::Bot
  configure { |config| config.token = "1:ECHO" }

  routes do
    text to: "echo#say"
  end
end
