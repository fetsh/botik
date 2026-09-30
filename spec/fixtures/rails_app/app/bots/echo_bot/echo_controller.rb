# frozen_string_literal: true

class EchoBot::EchoController < Botik::Controller
  def say
    reply update.text
  end
end
