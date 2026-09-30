# frozen_string_literal: true

module Botik
  # Builders for reply markup.
  #
  #   Botik::Keyboard.inline do |k|
  #     k.row do
  #       k.button "Yes", callback: "vote/yes"
  #       k.button "No",  callback: "vote/no"
  #     end
  #     k.button "Open site", url: "https://example.com"   # a button outside +row+ gets its own row
  #   end
  #   # => { inline_keyboard: [[{text: "Yes", callback_data: "vote/yes"}, ...], [...]] }
  #
  #   Botik::Keyboard.reply(resize: true, one_time: true) do |k|
  #     k.button "Share phone", request_contact: true
  #   end
  #
  #   Botik::Keyboard.remove        # => { remove_keyboard: true }
  #   Botik::Keyboard.force_reply   # => { force_reply: true }
  #
  # Blocks may also omit the argument and call +row+/+button+ directly, but then
  # +self+ changes to the builder, so helpers and instance variables of the caller
  # are not reachable. In views prefer the <tt>|k|</tt> form.
  class Keyboard
    def self.inline(&)
      { inline_keyboard: new(inline: true).build(&) }
    end

    def self.reply(resize: true, one_time: false, persistent: nil, selective: nil, placeholder: nil, &)
      {
        keyboard: new(inline: false).build(&),
        resize_keyboard: resize,
        one_time_keyboard: one_time,
        is_persistent: persistent,
        selective: selective,
        input_field_placeholder: placeholder
      }.compact
    end

    def self.remove(selective: nil)
      { remove_keyboard: true, selective: selective }.compact
    end

    def self.force_reply(placeholder: nil, selective: nil)
      { force_reply: true, input_field_placeholder: placeholder, selective: selective }.compact
    end

    def initialize(inline:)
      @inline = inline
      @rows = []
      @current_row = nil
    end

    def build(&block)
      block.arity.zero? ? instance_exec(&block) : yield(self)
      @rows
    end

    def row
      raise ArgumentError, "rows can't be nested" if @current_row

      @current_row = []
      yield
      @rows << @current_row unless @current_row.empty?
      self
    ensure
      @current_row = nil
    end

    # Adds a button. For inline keyboards +callback:+ is a shortcut for
    # +callback_data:+; any other Telegram button field (url, web_app,
    # switch_inline_query, request_contact, ...) is passed through.
    def button(text, callback: nil, **options)
      options[:callback_data] = callback if callback
      if @inline && options.empty?
        raise ArgumentError, "inline button #{text.inspect} needs callback:, url: or another action"
      end

      button = { text: text.to_s, **options }
      @current_row ? @current_row << button : @rows << [button]
      self
    end
  end
end
