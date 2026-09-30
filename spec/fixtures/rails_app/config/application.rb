# frozen_string_literal: true

require "rails"
require "botik"

class EchoApp < Rails::Application
  config.root = File.expand_path("..", __dir__)
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "test"
end

EchoApp.initialize!
