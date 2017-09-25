module Botik
  module Helpers
    def Helpers.send_message(message_class, opts: {}, with:, to:)
      message = message_class.new(opts)
      if message.photo
        if message.caption.size > 200
          res = with.api.send_message(message.to(to).except(:caption))
          with.api.send_photo(message.to(to).except(:text, :caption).merge(
            disable_notification: true,
            reply_to_message_id: res['result']['message_id']
          ))
        else
          with.api.send_photo(message.to(to).except(:text))
        end
      else
        with.api.send_message(message.to(to))
      end
    end

    def edit_message(message_class, opts: {}, with:, to:, message_id:)
      message = message_class.new(opts)
      if message.text.present?
        with.api.edit_message_text(message.to(to).merge(message_id: message_id))
      else
        with.api.edit_message_reply_markup(message.to(to).merge(message_id: message_id).except(:text))
      end
    end
  end
end
