# frozen_string_literal: true

module Botik
  # An incoming Telegram update with convenience accessors on top of Payload.
  #
  #   update.type          # => :message, :callback_query, :inline_query, ...
  #   update.object        # => the payload of that type (the Message, the CallbackQuery, ...)
  #   update.message       # => the raw "message" field (nil for other update types)
  #   update.effective_message  # => a message for any message-like update, including
  #                             #    the message a callback button is attached to
  #   update.chat, update.from, update.text, update.command, update.callback_data
  class Update < Payload
    # Update types that carry a Message object.
    MESSAGE_TYPES = %i[
      message edited_message channel_post edited_channel_post
      business_message edited_business_message
    ].freeze

    # A parsed bot command: "/start@my_bot ref42" => name "start", username "my_bot", args "ref42".
    Command = Data.define(:name, :username, :args) do
      def argv
        args.split
      end
    end

    # Accepts a Hash, a JSON string or an Update.
    def self.parse(input)
      case input
      when Update then input
      when String then new(JSON.parse(input))
      when Payload then new(input.to_h)
      when Hash then new(input)
      else raise ArgumentError, "can't build an Update from #{input.class}"
      end
    end

    def id
      self[:update_id]
    end

    def type
      return @type if defined?(@type)

      @type = keys.find { |key| key != "update_id" }&.to_sym
    end

    # The object of this update's type: the Message for +message+, the CallbackQuery
    # for +callback_query+ and so on.
    def object
      type && self[type]
    end

    def message_type?
      MESSAGE_TYPES.include?(type)
    end

    # The message behind the update. For callback queries it is the message the
    # inline keyboard is attached to.
    def effective_message
      if message_type? then object
      elsif type == :callback_query then object.message
      end
    end

    def chat
      effective_message&.chat || object&.chat
    end

    # The user who triggered the update.
    def from
      return nil unless object

      object.from || object.user
    end

    def chat_id
      chat&.id
    end

    def user_id
      from&.id
    end

    # Text (or caption) of a message-like update.
    def text
      return nil unless message_type?

      object.text || object.caption
    end

    def callback_data
      object.data if type == :callback_query
    end

    def callback_query?
      type == :callback_query
    end

    # The bot command that starts the message text, or nil.
    def command
      return @command if defined?(@command)

      @command = parse_command
    end

    def command?
      !command.nil?
    end

    private

    def parse_command
      return nil unless message_type? && object.text

      entity = Array(object.entities).find { |e| e.type == "bot_command" && e.offset.to_i.zero? }
      return nil unless entity

      text = object.text
      name, username = text[1...entity.length].split("@", 2)
      Command.new(name: name, username: username, args: text[entity.length..].to_s.strip)
    end
  end
end
