require 'active_support/core_ext/module/delegation'
module Botik
  class Message
    delegate :each_with_object, to: :message

    attr_accessor :opts

    def initialize(opts = {})
      @opts = opts
    end

    [
      :text, :parse_mode, :disable_web_page_preview,
      :disable_notification, :reply_to_message_id, :reply_markup,
      :caption, :photo, :document, :message_id
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
        photo: photo,
        caption: caption,
        document: document,
        parse_mode: parse_mode,
        disable_web_page_preview: disable_web_page_preview,
        disable_notification: disable_notification,
        reply_to_message_id: reply_to_message_id,
        reply_markup: reply_markup
      }
    end

    def chat_id
      return nil unless opts[:update]
      opts[:update].callback_query.message.chat.id if opts[:update].callback?
      opts[:update].chat.id
    end

    def message_id
      return nil unless opts[:update]
      opts[:update].callback_query.message.message_id if opts[:update].callback?
    end

    def to(id)
      message.merge(chat_id: id)
    end
  end
end
