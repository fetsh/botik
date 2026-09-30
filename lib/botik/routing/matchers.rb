# frozen_string_literal: true

module Botik
  module Routing
    # Matchers decide whether an update fits a route and extract params from it.
    # Each returns a params Hash on success and nil otherwise.
    module Matchers
      # "/start ref42" — matches message-like updates whose text starts with one of the commands.
      class Command
        def initialize(names, types:)
          @names = Array(names).map { |name| name.to_s.delete_prefix("/").downcase }
          @types = types
        end

        def call(update, bot)
          command = update.command
          return nil unless command && @types.include?(update.type)
          return nil unless @names.include?(command.name.downcase)
          return nil if command.username && bot.config.username &&
                        !command.username.casecmp?(bot.config.username)

          { command: command.name, args: command.args }
        end

        def describe
          @names.map { |name| "/#{name}" }.join(", ")
        end
      end

      # Text of a message-like update: exact string, Regexp (named captures become
      # params) or nil for any text.
      class Text
        def initialize(pattern, types:)
          @pattern = pattern
          @types = types
        end

        def call(update, _bot)
          text = update.text
          return nil unless text && @types.include?(update.type)

          case @pattern
          when nil then { text: text }
          when Regexp then regexp_params(@pattern.match(text), text)
          else text == @pattern.to_s ? { text: text } : nil
          end
        end

        def describe
          @pattern.nil? ? "(any text)" : @pattern.inspect
        end

        private

        def regexp_params(match, text)
          return nil unless match

          params = { text: text, match: match }
          params.merge!(match.named_captures.transform_keys(&:to_sym)) if match.names.any?
          params
        end
      end

      # Message-like updates, optionally only those carrying a given field
      # (:photo, :document, :location, :contact, ...).
      class Message
        def initialize(kinds, types:)
          @kinds = Array(kinds).map(&:to_s)
          @types = types
        end

        def call(update, _bot)
          return nil unless @types.include?(update.type)
          return {} if @kinds.empty?

          kind = @kinds.find { |name| update.object.key?(name) }
          kind && { kind: kind.to_sym }
        end

        def describe
          @kinds.empty? ? "(any message)" : @kinds.join(", ")
        end
      end

      # Callback query data. A String pattern supports :named segments and a
      # trailing *splat ("orders/:id/*rest"); a Regexp works like in Text; nil
      # matches any callback query.
      class Callback
        def initialize(pattern)
          @pattern = pattern
          @regexp = compile(pattern)
        end

        def call(update, _bot)
          return nil unless update.callback_query?

          data = update.callback_data.to_s
          return { data: data } if @regexp.nil?

          match = @regexp.match(data)
          match && { data: data }.merge!(match.named_captures.transform_keys(&:to_sym))
        end

        def describe
          @pattern.nil? ? "(any callback)" : @pattern.inspect
        end

        private

        def compile(pattern)
          case pattern
          when nil then nil
          when Regexp then pattern
          else
            source = Regexp.escape(pattern.to_s)
                           .gsub(/\\\*(\w+)\z/) { "(?<#{Regexp.last_match(1)}>.*)" }
                           .gsub(/:(\w+)/) { "(?<#{Regexp.last_match(1)}>[^/:]+)" }
            Regexp.new("\\A#{source}\\z")
          end
        end
      end

      # Any update of the given type(s) (:inline_query, :poll_answer, :my_chat_member, ...).
      class Type
        def initialize(types)
          @types = Array(types).map(&:to_sym)
        end

        def call(update, _bot)
          @types.include?(update.type) ? {} : nil
        end

        def describe
          @types.join(", ")
        end
      end

      # Matches everything; used by +default+.
      class Any
        def call(_update, _bot)
          {}
        end

        def describe
          "*"
        end
      end
    end
  end
end
