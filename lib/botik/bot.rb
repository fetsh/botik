# frozen_string_literal: true

module Botik
  # A bot: its configuration, routes, middleware and API client. Subclass it
  # once per bot; the subclass is also the namespace of its controllers.
  #
  #   class SupportBot < Botik::Bot
  #     configure do |config|
  #       config.token = ENV.fetch("SUPPORT_BOT_TOKEN")
  #       config.username = "acme_support_bot"
  #       config.webhook_secret = ENV.fetch("SUPPORT_BOT_WEBHOOK_SECRET")
  #     end
  #
  #     routes do
  #       command :start, to: "welcome#start"    # => SupportBot::WelcomeController#start
  #       default to: "welcome#unknown"
  #     end
  #   end
  #
  #   SupportBot.call(update_hash)   # process one update
  #   SupportBot.webhook             # Rack app for Telegram webhooks
  #   SupportBot.poll                # long polling loop
  #   SupportBot.client.get_me       # raw API
  #
  # Several bots in one project are just several subclasses. A subclass of a
  # bot inherits its configuration, routes, middleware and controllers, which
  # allows running the same bot under many tokens:
  #
  #   tenant_bot = Class.new(SupportBot) { configure { |c| c.token = tenant.token } }
  class Bot
    class << self
      def inherited(subclass)
        super
        Botik.bot_names << subclass.name if subclass.name && !Botik.bot_names.include?(subclass.name)
      end

      # This bot's configuration. Unset options fall back to the parent bot and
      # then to Botik.config.
      def config
        @config ||= Configuration.new(superclass.respond_to?(:config) ? superclass.config : Botik.config)
      end

      def configure
        yield config
        @client = nil
        self
      end

      # Draws routes (appending to existing ones) and returns the route set.
      # A bot without its own routes uses its parent's.
      def routes(&block)
        if block
          @routes ||= Routing::RouteSet.new
          @routes.draw(&block)
        end
        @routes || (superclass.respond_to?(:routes) ? superclass.routes : Routing::RouteSet.new)
      end

      def middleware
        @middleware ||= superclass.respond_to?(:middleware) ? superclass.middleware.dup : MiddlewareStack.new
      end

      def use(...)
        middleware.use(...)
      end

      # The API client, built from the configuration (or config.client).
      def client
        @client ||= config.client || Client.new(
          config.token, api_url: config.api_url, timeout: config.timeout, open_timeout: config.open_timeout
        )
      end
      alias api client

      attr_writer :client

      def logger
        config.logger
      end

      # Module holding the controllers: config.controller_namespace or the bot
      # class (the nearest named ancestor for anonymous subclasses).
      def controller_namespace
        config.controller_namespace || named_ancestor&.name
      end

      # Telegram's numeric id of the bot (the part of the token before ":"),
      # falling back to the class name. Used to separate sessions of different bots.
      def bot_id
        config.token.to_s.split(":").first.presence || named_ancestor&.name || object_id.to_s
      end

      # Processes one update synchronously. Accepts a Hash, a JSON String or a
      # Botik::Update. Returns the controller (or the endpoint's result), or nil
      # when no route matched.
      def call(update)
        update = Update.parse(update)
        request = Request.new(self, update)
        ActiveSupport::Notifications.instrument("process_update.botik", bot: self, update: update) do
          result = middleware.build(method(:route)).call(request)
          # Like a database transaction: the session is saved only if processing succeeded.
          request.session.commit if request.session_loaded?
          result
        end
      end

      # A Rack app that receives Telegram webhooks (see Botik::Webhook).
      def webhook
        Webhook.new(self)
      end

      def poller(**)
        Poller.new(self, **)
      end

      # Starts long polling (see Botik::Poller). Blocks until stopped.
      def poll(**)
        poller(**).run
      end

      # Registers +url+ as the webhook, with config.webhook_secret as the secret token.
      def set_webhook(url, **)
        client.set_webhook(url: url, secret_token: config.webhook_secret, **)
      end

      def delete_webhook(**)
        client.delete_webhook(**)
      end

      # Reports an error that happened outside a controller (in the webhook or
      # the poller) via config.error_handler, or logs it.
      def handle_error(exception, update = nil)
        if config.error_handler
          config.error_handler.call(exception, update)
        else
          logger.error("[botik] #{name} failed to process update #{update&.id}: " \
                       "#{exception.class}: #{exception.message}\n#{Array(exception.backtrace).first(10).join("\n")}")
        end
      end

      private

      def route(request)
        route, params = routes.recognize(request)
        unless route
          logger.debug { "[botik] #{name}: no route for #{request.update.type} update #{request.update.id}" }
          return nil
        end

        request.route = route
        request.params.merge!(params)
        route.dispatch(request)
      end

      def named_ancestor
        ancestors.find { |klass| klass.is_a?(Class) && klass.name && klass <= Bot && klass != Bot }
      end
    end
  end
end
