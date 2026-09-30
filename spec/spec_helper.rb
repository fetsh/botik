# frozen_string_literal: true

require "botik"
require "botik/testing"
require "webmock/rspec"
require "logger"
require "stringio"

Botik.configure do |config|
  config.logger = Logger.new(nil)
  config.view_paths = [File.expand_path("fixtures/views", __dir__)]
end

Dir[File.join(__dir__, "support/**/*.rb")].each { |file| require file }

RSpec.configure do |config|
  config.include Botik::Testing::Helpers
  config.disable_monkey_patching!
  config.order = :random
  config.example_status_persistence_file_path = "tmp/rspec_status"

  config.before do
    Botik.config.session_store.clear
  end
end
