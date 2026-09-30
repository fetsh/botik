# frozen_string_literal: true

module Botik
  module Testing
    # Builders of realistic update hashes for tests.
    #
    #   Updates.message("/start ref42")                       # entities for the command are added
    #   Updates.message("hi", chat: { id: -100, type: "group" })
    #   Updates.message(photo: [{ file_id: "abc", width: 1, height: 1 }])
    #   Updates.callback_query("orders/7/confirm")
    #   Updates.update(:inline_query, id: "1", query: "cats")
    module Updates
      DEFAULT_USER = { "id" => 100, "is_bot" => false, "first_name" => "Test", "username" => "tester" }.freeze
      DEFAULT_CHAT = { "id" => 100, "type" => "private", "first_name" => "Test", "username" => "tester" }.freeze

      module_function

      def next_id
        @next_id = (@next_id || 0) + 1
      end

      def message(text = nil, chat: {}, from: {}, type: :message, update_id: next_id, **fields)
        message = {
          "message_id" => next_id,
          "date" => Time.now.to_i,
          "chat" => DEFAULT_CHAT.merge(stringify(chat)),
          "from" => DEFAULT_USER.merge(stringify(from))
        }
        if text
          message["text"] = text
          if (command = text[%r{\A/[A-Za-z0-9_]+(@\w+)?}])
            message["entities"] = [{ "type" => "bot_command", "offset" => 0, "length" => command.length }]
          end
        end
        message.merge!(stringify(fields))
        { "update_id" => update_id, type.to_s => message }
      end

      def callback_query(data, message: {}, from: {}, update_id: next_id, **fields)
        original = message("button message", **message.transform_keys(&:to_sym))["message"]
        query = {
          "id" => next_id.to_s,
          "from" => DEFAULT_USER.merge(stringify(from)),
          "chat_instance" => "1",
          "data" => data,
          "message" => original
        }.merge(stringify(fields))
        { "update_id" => update_id, "callback_query" => query }
      end

      def update(type, object = {}, update_id: next_id, **fields)
        object = { "from" => DEFAULT_USER.dup }.merge(stringify(object)).merge(stringify(fields))
        { "update_id" => update_id, type.to_s => object }
      end

      def stringify(hash)
        JSON.parse(JSON.generate(hash))
      end
    end
  end
end
