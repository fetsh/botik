# frozen_string_literal: true

require "rails/generators/named_base"

module Botik
  module Generators
    # rails generate botik:bot support
    #
    # Creates SupportBot in app/bots with an application controller, a start
    # controller and its view, and mounts the webhook in config/routes.rb.
    class BotGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      class_option :skip_route, type: :boolean, default: false, desc: "Don't mount the webhook in config/routes.rb"

      def create_bot
        template "bot.rb.tt", "app/bots/#{bot_file_name}.rb"
      end

      def create_controllers
        template "application_controller.rb.tt", "app/bots/#{bot_file_name}/application_controller.rb"
        template "start_controller.rb.tt", "app/bots/#{bot_file_name}/start_controller.rb"
      end

      def create_views
        template "start.html.erb.tt", "app/views/#{bot_file_name}/start/show.html.erb"
        template "help.html.erb.tt", "app/views/#{bot_file_name}/start/help.html.erb"
      end

      def mount_webhook
        return if options[:skip_route] || !File.exist?(File.join(destination_root, "config/routes.rb"))

        route %(mount #{bot_class_name}.webhook => "/telegram/#{bot_base_name}")
      end

      private

      def bot_base_name
        file_name.delete_suffix("_bot")
      end

      def bot_file_name
        "#{bot_base_name}_bot"
      end

      def bot_class_name
        bot_file_name.camelize
      end

      def env_prefix
        bot_file_name.upcase
      end
    end
  end
end
