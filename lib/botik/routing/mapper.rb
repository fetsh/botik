# frozen_string_literal: true

module Botik
  module Routing
    # The routing DSL, evaluated inside +routes do ... end+ of a bot.
    #
    # Routes are checked in the order they are defined; the first match wins.
    #
    #   routes do
    #     command :start, to: "welcome#start"
    #     command %i[help h], to: "help#show"
    #
    #     callback "orders/:id/confirm", to: "orders#confirm"
    #     callback /\Apage:(?<page>\d+)\z/, to: "catalog#page"
    #
    #     scope chat_type: :private do
    #       scope state: :awaiting_email do
    #         text to: "signup#email"
    #       end
    #       message :photo, to: "photos#create"
    #       text /\Ahi|hello\z/i, to: "greetings#hello"
    #     end
    #
    #     namespace :admin, if: ->(request) { ADMIN_IDS.include?(request.update.user_id) } do
    #       command :stats, to: "stats#show"      # => Admin::StatsController#show
    #     end
    #
    #     on :inline_query, to: "search#inline"
    #     on :my_chat_member, to: ->(request) { ... }
    #
    #     default to: "fallback#unknown"
    #   end
    #
    # Every route accepts constraints:
    # +chat_type:+ (:private, :group, :supergroup, :channel),
    # +state:+ (compared with <tt>session[:state]</tt>),
    # +if:+ / +unless:+ (callables receiving the Botik::Request).
    #
    # Message-based routes (command, text, message) match +:message+,
    # +:channel_post+ and +:business_message+ updates. Pass +types:+ to change that,
    # e.g. <tt>text to: "edits#create", types: [:edited_message]</tt>.
    class Mapper
      DEFAULT_MESSAGE_TYPES = %i[message channel_post business_message].freeze
      CONSTRAINTS = %i[chat_type state if unless].freeze

      def initialize(route_set)
        @route_set = route_set
        @scope = { namespace: nil, constraints: {} }
      end

      def command(names, to:, types: DEFAULT_MESSAGE_TYPES, **constraints)
        add(:command, Matchers::Command.new(names, types: Array(types)), to, constraints)
      end

      def text(pattern = nil, to:, types: DEFAULT_MESSAGE_TYPES, **constraints)
        add(:text, Matchers::Text.new(pattern, types: Array(types)), to, constraints)
      end

      def message(*kinds, to:, types: DEFAULT_MESSAGE_TYPES, **constraints)
        add(:message, Matchers::Message.new(kinds, types: Array(types)), to, constraints)
      end

      def callback(pattern = nil, to:, **constraints)
        add(:callback, Matchers::Callback.new(pattern), to, constraints)
      end

      def on(*types, to:, **constraints)
        add(:on, Matchers::Type.new(types), to, constraints)
      end

      def default(to:, **constraints)
        add(:default, Matchers::Any.new, to, constraints)
      end

      # Applies constraints to every route inside the block.
      def scope(**constraints, &)
        nested(namespace: @scope[:namespace], constraints: constraints, &)
      end

      # Prefixes controllers inside the block: <tt>namespace :admin</tt> turns
      # "users#index" into Admin::UsersController.
      def namespace(name, **constraints, &)
        path = [@scope[:namespace], name.to_s].compact.join("/")
        nested(namespace: path, constraints: constraints, &)
      end

      private

      def nested(namespace:, constraints:)
        validate_constraints!(constraints)
        previous = @scope
        begin
          @scope = { namespace: namespace, constraints: merge_constraints(previous[:constraints], constraints) }
          yield
        ensure
          @scope = previous
        end
      end

      def add(kind, matcher, to, constraints)
        validate_constraints!(constraints)
        @route_set.add Route.new(
          kind: kind,
          matcher: matcher,
          endpoint: endpoint(to),
          constraints: merge_constraints(@scope[:constraints], constraints)
        )
      end

      def endpoint(to)
        return to if to.respond_to?(:call)

        controller, action = to.to_s.split("#", 2)
        if controller.to_s.empty? || action.to_s.empty?
          raise RoutingError, "route target must look like \"controller#action\", got #{to.inspect}"
        end

        [@scope[:namespace], controller].compact.join("/") + "##{action}"
      end

      # Inner if/unless conditions are combined with outer ones; other
      # constraints are overridden by the inner scope.
      def merge_constraints(outer, inner)
        merged = outer.merge(inner)
        %i[if unless].each do |key|
          next unless outer[key] && inner[key]

          first = outer[key]
          second = inner[key]
          merged[key] = if key == :if
                          ->(request) { first.call(request) && second.call(request) }
                        else
                          ->(request) { first.call(request) || second.call(request) }
                        end
        end
        merged
      end

      def validate_constraints!(constraints)
        unknown = constraints.keys - CONSTRAINTS
        return if unknown.empty?

        raise ArgumentError, "unknown route option(s): #{unknown.join(', ')}"
      end
    end
  end
end
