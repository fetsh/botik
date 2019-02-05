require 'active_support/core_ext/module/delegation'
module Botik
  class EditMessage
    delegate :each_with_object, to: :message

    attr_accessor :opts

    def initialize(opts = {})
      @opts = opts
    end

    [
      :text, :parse_mode, :disable_web_page_preview, :reply_markup
    ].each do |s|
      define_method(s) do
        nil
      end
    end

    def message
      {
        text: text,
        chat_id: chat_id,
        message_id: message_id,
        parse_mode: parse_mode,
        disable_web_page_preview: disable_web_page_preview,
        reply_markup: reply_markup
      }
    end

    def chat_id
      opts[:update].callback_query.message.chat.id if opts[:update]
    end

    def message_id
      opts[:update].callback_query.message.message_id if opts[:update]
    end

    def to(id)
      message.merge(chat_id: id)
    end
  end
end
