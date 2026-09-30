# frozen_string_literal: true

module Botik
  class Controller
    # Helpers that respond to the current update. Each of them marks the action as
    # performed (so implicit rendering is skipped and a before_action halts) and
    # records the API result in +responses+.
    module Messaging
      # Sends a text message to the current chat. Without text, renders the
      # current action's template (the same as +render+).
      #
      #   reply "Hello!"
      #   reply "<b>Hi</b>", parse_mode: "HTML", reply_markup: inline_keyboard { |k| ... }
      def reply(text = nil, **options)
        return render(**options) if text.nil? && !options.key?(:text)

        respond(:send_message, chat_id: chat_id!, text: text, **options)
      end

      # Sends any "send*" method to the current chat:
      #
      #   reply_with :photo, photo: File.open("cat.jpg"), caption: "Meow"
      #   reply_with :location, latitude: 31.8, longitude: 34.6
      def reply_with(kind, **params)
        respond(:"send_#{kind}", chat_id: chat_id!, **params)
      end

      # Edits the message the callback button belongs to (or +message_id:+).
      # Pass text, or +template:+ to render one; with neither, only the reply
      # markup is edited.
      #
      #   edit_message "Done ✅"
      #   edit_message template: :show
      #   edit_message reply_markup: Botik::Keyboard.inline { |k| ... }
      def edit_message(text = nil, template: nil, locals: {}, message_id: nil, **options)
        inline_id = update.object.inline_message_id if update.callback_query? && message_id.nil?
        target = if inline_id
                   { inline_message_id: inline_id }
                 else
                   { chat_id: chat_id!, message_id: message_id || effective_message&.message_id }
                 end

        params = template ? render_to_string(template, locals: locals).to_params : {}
        params[:text] = text if text
        params.merge!(options)

        if params.key?(:text)
          respond(:edit_message_text, **target, **params)
        else
          respond(:edit_message_reply_markup, **target, **params)
        end
      end

      # Deletes a message (by default the current one).
      def delete_message(message_id = effective_message&.message_id)
        respond(:delete_message, chat_id: chat_id!, message_id: message_id)
      end

      # Answers the current callback query (a toast, or an alert with +show_alert: true+).
      def answer_callback_query(text = nil, **)
        @_callback_answered = true
        respond(:answer_callback_query, callback_query_id: update.object.id, text: text, **)
      end

      def answer_inline_query(results, **)
        respond(:answer_inline_query, inline_query_id: update.object.id, results: results, **)
      end

      # Shows "typing…" (or another action). Does not count as a response.
      def chat_action(action = :typing)
        api.send_chat_action(chat_id: chat_id!, action: action.to_s)
      end

      def inline_keyboard(&)
        Keyboard.inline(&)
      end

      def reply_keyboard(**, &)
        Keyboard.reply(**, &)
      end

      # Results of the API calls made through the helpers above.
      def responses
        @_responses ||= []
      end

      def performed?
        !responses.empty?
      end

      private

      def respond(api_method, **params)
        result = api.public_send(api_method, **params)
        responses << result
        result
      end

      def chat_id!
        chat&.id or raise Error, "update #{update.id} (#{update.type}) has no chat to reply to"
      end
    end
  end
end
