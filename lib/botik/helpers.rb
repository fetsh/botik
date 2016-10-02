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
  end
end
