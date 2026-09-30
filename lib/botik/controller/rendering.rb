# frozen_string_literal: true

module Botik
  class Controller
    # Rendering of ERB views. Views live in the bot's view paths under the
    # controller path: SupportBot::OrdersController#show renders
    # +app/views/support_bot/orders/show.html.erb+ (or +.md.erb+ / +.text.erb+).
    module Rendering
      extend ActiveSupport::Concern

      included do
        class_attribute :_helpers, instance_accessor: false, default: Module.new
      end

      class_methods do
        # Makes helper modules available in this controller's views.
        def helper(*modules)
          helpers = Module.new
          helpers.include(_helpers)
          modules.each { |mod| helpers.include(mod) }
          self._helpers = helpers
        end

        # Exposes controller methods to views:
        #   helper_method :current_user
        def helper_method(*names)
          helpers = Module.new
          helpers.include(_helpers)
          names.each do |name|
            helpers.define_method(name) { |*args, **kwargs, &block| controller.send(name, *args, **kwargs, &block) }
          end
          self._helpers = helpers
        end
      end

      # Renders a template (by default the current action's) and sends it as a
      # message to the current chat. Extra options go to sendMessage:
      #
      #   render                                # orders/show for OrdersController#show
      #   render :summary, locals: { total: 3 }
      #   render "shared/help"                  # <bot>/shared/help, then shared/help
      #   render plain: "Just text"
      #   render :show, reply_markup: Botik::Keyboard.remove, disable_notification: true
      def render(template = nil, plain: nil, locals: {}, **)
        if plain
          reply(plain, **)
        else
          reply(**render_to_string(template || action_name, locals: locals).to_params, **)
        end
      end

      # Renders a template without sending anything. Returns View::Rendered
      # (text, parse_mode, reply_markup).
      def render_to_string(template = action_name, locals: {})
        template_object = view_resolver.find!(template, prefix: self.class.controller_path, namespace: view_namespace)
        context = view_context
        text = template_object.render(context, locals).strip
        View::Rendered.new(text: text, parse_mode: template_object.format.parse_mode,
                           reply_markup: context.reply_markup)
      end

      # Whether a template exists for +template+ (the current action by default).
      def template_exists?(template = action_name)
        !view_resolver.find(template, prefix: self.class.controller_path, namespace: view_namespace).nil?
      end

      # The bot's view directory ("shop_bot" for ShopBot), where templates given
      # as paths ("shared/help") are looked up first.
      def view_namespace
        bot.controller_namespace&.underscore
      end

      def view_resolver
        @_view_resolver ||= View::Resolver.new(bot.config.view_paths)
      end

      def view_context
        View::Context.new(self, assigns: view_assigns, helpers: [self.class._helpers])
      end

      # Instance variables passed to views (all except internal ones starting with "_").
      def view_assigns
        instance_variables.each_with_object({}) do |name, assigns|
          key = name.to_s.delete_prefix("@")
          assigns[key] = instance_variable_get(name) unless key.start_with?("_")
        end
      end
    end
  end
end
