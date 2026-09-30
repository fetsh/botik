# frozen_string_literal: true

module Botik
  module Routing
    # A single routing rule: a matcher, optional constraints and an endpoint
    # (a controller action or a callable).
    class Route
      attr_reader :kind, :matcher, :constraints, :endpoint

      def initialize(kind:, matcher:, endpoint:, constraints: {})
        @kind = kind
        @matcher = matcher
        @endpoint = endpoint
        @constraints = constraints
      end

      # Returns params when the route matches the request, nil otherwise.
      def match(request)
        return nil unless constraints_satisfied?(request)

        matcher.call(request.update, request.bot)
      end

      # Runs the endpoint. Controller endpoints ("controller#action") are resolved
      # at dispatch time, which keeps them compatible with code reloading.
      def dispatch(request)
        if endpoint.respond_to?(:call)
          endpoint.call(request)
        else
          controller_class(request.bot).dispatch(action, request)
        end
      end

      def controller
        endpoint.respond_to?(:call) ? nil : endpoint.split("#", 2).first
      end

      def action
        endpoint.respond_to?(:call) ? nil : endpoint.split("#", 2).last
      end

      def controller_class(bot)
        name = "#{controller.camelize}Controller"
        namespace = bot.controller_namespace
        full_name = namespace ? "#{namespace}::#{name}" : name
        full_name.constantize
      rescue NameError => e
        raise unless e.name.nil? || full_name.include?(e.name.to_s)

        raise RoutingError, "#{full_name} is not defined (route #{self})"
      end

      def to_s
        conditions = constraints.except(:if).map { |key, value| "#{key}: #{Array(value).join('|')}" }
        conditions << "if: <proc>" if constraints[:if]
        target = endpoint.respond_to?(:call) ? "<proc>" : endpoint
        [kind.to_s.ljust(8), matcher.describe.ljust(24), "=> #{target}", conditions.join(", ")]
          .join(" ").strip
      end

      private

      def constraints_satisfied?(request)
        constraints.all? do |name, value|
          case name
          when :chat_type then Array(value).map(&:to_s).include?(request.update.chat&.type.to_s)
          when :state then Array(value).map(&:to_s).include?(request.session["state"].to_s)
          when :if then value.call(request)
          when :unless then !value.call(request)
          else raise RoutingError, "unknown route constraint #{name.inspect}"
          end
        end
      end
    end
  end
end
