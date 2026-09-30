# frozen_string_literal: true

module Botik
  # Rails integration: Rails.logger, app/views, Rails.error reporting, rake tasks.
  # Bots live in app/bots (autoloaded by Rails): app/bots/support_bot.rb defines
  # SupportBot, app/bots/support_bot/*_controller.rb its controllers.
  class Railtie < Rails::Railtie
    initializer "botik.defaults" do |app|
      config = Botik.config
      config.logger = Rails.logger unless config.set?(:logger)
      config.view_paths = [app.root.join("app/views").to_s] unless config.set?(:view_paths)
      unless config.set?(:error_handler)
        config.error_handler = lambda do |exception, update|
          Rails.logger.error("[botik] update #{update&.id} failed: #{exception.class}: #{exception.message}")
          Rails.error.report(exception, handled: true, context: { telegram_update: update&.to_h })
        end
      end
    end

    rake_tasks do
      load File.expand_path("tasks.rake", __dir__)
    end
  end
end
