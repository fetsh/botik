module Botik
  module Helpers
    def Helpers.send_message(message_class, opts: {}, with:, to:)
      with.api.send_message(message_class.new(opts).to(to))
    end

    def Helpers.send_photo(message_class, opts: {}, with:, to:)
      with.api.send_photo(message_class.new(opts).to(to).except(:text))
    end

    def Helpers.edit_message(message_class, opts: {}, with:, to:, message_id:)
      message = message_class.new(opts)
      if message.text.present?
        with.api.edit_message_text(message.to(to).merge(message_id: message_id))
      else
        with.api.edit_message_reply_markup(message.to(to).merge(message_id: message_id).except(:text))
      end
    end
  end
end
