module Telegram::Bot::Types::Compactable
  def to_hash_recursive
    Hash[attributes.dup.delete_if { |_, v| v.nil? }.map do |key, value|
      value =
        if value.class.ancestors.include?(Telegram::Bot::Types::Compactable)
          value.to_hash_recursive
        elsif value.is_a?(Array)
          value.map do |item|
            if item.class.ancestors.include?(Telegram::Bot::Types::Compactable)
              item.to_hash_recursive
            else
              item
            end
          end
        else
          value
        end
      [key, value]
    end]
  end
end

class Telegram::Bot::Types::User
  def to_s
    "#{id}:#{' @' + username if username} (#{first_name} #{last_name})"
  end
end

class Telegram::Bot::Types::Update
  def incoming
    inline_query || chosen_inline_result || callback_query ||
      edited_message || message || channel_post
  end

  def chat
    if incoming.respond_to?(:chat) && !incoming.chat.nil?
      incoming.chat
    else
      incoming.from
    end
  end

  def message?
    !text_message.nil?
  end

  def text_message?
    message? && text_message.text
  end

  def text_message
    message || edited_message
  end

  def command_message?
    text_message? && text_message.entities && command_entity
  end

  def command_entity
    text_message.entities.find do |e|
      e.type == 'bot_command' && e.offset.zero?
    end
  end

  def command
    @cmd ||= begin
      return nil unless command_message?
      text_message.text[1..command_entity.length - 1]
    end
  end

  def callback?
    !callback_query.nil?
  end
end
