# frozen_string_literal: true

module Botik
  module Routing
    # The ordered list of a bot's routes.
    class RouteSet
      include Enumerable

      def initialize
        @routes = []
      end

      # Evaluates the routing DSL. Can be called several times; routes are appended.
      def draw(&)
        Mapper.new(self).instance_exec(&)
        self
      end

      def add(route)
        @routes << route
        route
      end

      def clear
        @routes.clear
        self
      end

      def each(&)
        @routes.each(&)
      end

      def empty?
        @routes.empty?
      end

      # Finds the first route matching the request. Returns [route, params] or nil.
      def recognize(request)
        @routes.each do |route|
          params = route.match(request)
          return [route, params] if params
        end
        nil
      end

      def to_s
        to_a.join("\n")
      end
    end
  end
end
