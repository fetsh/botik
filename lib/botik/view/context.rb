# frozen_string_literal: true

module Botik
  module View
    # What a template renders into.
    Rendered = Data.define(:text, :parse_mode, :reply_markup) do
      # Parameters for sendMessage/editMessageText.
      def to_params
        { text: text, parse_mode: parse_mode, reply_markup: reply_markup }.compact
      end
    end

    # The +self+ of a template: exposes the controller's instance variables, the
    # view helpers, the bot's helper modules and <tt>helper_method</tt>s.
    class Context
      include CompiledTemplates
      include Helpers

      attr_accessor :reply_markup
      attr_reader :controller

      def initialize(controller, assigns: {}, helpers: [])
        @controller = controller
        assigns.each { |name, value| instance_variable_set(:"@#{name}", value) }
        helpers.each { |helper| extend helper }
      end

      delegate :params, :session, :update, :chat, :from, :bot, to: :controller

      # Renders a partial: <tt><%= render "item", item: item %></tt> looks up
      # +_item.<format>.erb+ next to the current controller's views;
      # <tt><%= render "shared/footer" %></tt> looks up +<bot>/shared/_footer+,
      # then +shared/_footer+. The trailing newline of a partial is dropped.
      def render(partial, locals = {})
        template = controller.view_resolver.find!(
          partial, prefix: controller.class.controller_path, namespace: controller.view_namespace,
                   partial: true, formats: current_format_extensions
        )
        SafeString.new(template.render(self, locals).chomp)
      end

      # Used by Template to switch formats while rendering partials.
      def with_format(format)
        previous = @_format
        @_format = format
        yield
      ensure
        @_format = previous
      end

      def current_format
        @_format || Formats::Text
      end

      private

      def current_format_extensions
        Formats::EXTENSIONS.select { |_, format| format == current_format }.keys
      end

      def _botik_escape(value)
        escape(value)
      end
    end
  end
end
