# frozen_string_literal: true

module Botik
  class Controller
    # before_action / after_action / around_action with the same options as in
    # Rails: +only:+, +except:+, +if:+, +unless:+.
    #
    # A before_action halts the chain when it responds (calls +reply+, +render+,
    # +edit_message+, ...) — just like a Rails before_action that renders.
    module Callbacks
      extend ActiveSupport::Concern

      included do
        define_callbacks :process_action,
                         terminator: lambda { |controller, result|
                           result.call if result.respond_to?(:call)
                           controller.performed?
                         },
                         skip_after_callbacks_if_terminated: true
      end

      class_methods do
        %i[before after around].each do |kind|
          define_method(:"#{kind}_action") do |*names, **options, &block|
            names << block if block
            conditions = normalize_callback_options(options)
            names.each { |name| set_callback(:process_action, kind, name, **conditions) }
          end

          define_method(:"prepend_#{kind}_action") do |*names, **options, &block|
            names << block if block
            conditions = normalize_callback_options(options).merge(prepend: true)
            names.each { |name| set_callback(:process_action, kind, name, **conditions) }
          end

          define_method(:"skip_#{kind}_action") do |*names, **options|
            conditions = normalize_callback_options(options)
            names.each { |name| skip_callback(:process_action, kind, name, **conditions) }
          end
        end

        private

        def normalize_callback_options(options)
          options = options.dup
          conditions = { if: Array(options.delete(:if)), unless: Array(options.delete(:unless)) }

          if (only = options.delete(:only))
            actions = Array(only).map(&:to_s)
            conditions[:if] = [-> { actions.include?(action_name) }, *conditions[:if]]
          end
          if (except = options.delete(:except))
            actions = Array(except).map(&:to_s)
            conditions[:unless] = [-> { actions.include?(action_name) }, *conditions[:unless]]
          end
          raise ArgumentError, "unknown callback option(s): #{options.keys.join(', ')}" if options.any?

          conditions.reject { |_, value| value.empty? }
        end
      end
    end
  end
end
