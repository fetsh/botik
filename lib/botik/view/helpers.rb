# frozen_string_literal: true

module Botik
  module View
    # Helpers available in every view. Formatting helpers produce markup for the
    # current template format and escape their arguments, so
    # <tt><%= bold(user.first_name) %></tt> is safe in both .html.erb and .md.erb.
    module Helpers
      %i[bold italic underline strike spoiler quote].each do |name|
        define_method(name) do |text|
          SafeString.new(current_format.public_send(name, escape(text)))
        end
      end

      def code(text)
        SafeString.new(current_format.code(escape_code(text)))
      end

      def pre(text, language = nil)
        SafeString.new(current_format.pre(escape_code(text), language))
      end

      def link(text, url)
        SafeString.new(current_format.link(escape(text), url))
      end

      # Marks a string as safe: it is inserted into the template as is.
      def raw(text)
        SafeString.new(text.to_s)
      end

      # Escapes text for the current format (unless it is already safe).
      def escape(text)
        text.is_a?(SafeString) ? text : current_format.escape(text)
      end

      def escape_code(text)
        text.is_a?(SafeString) ? text : current_format.escape_code(text)
      end

      # Sets the reply markup of the message being rendered.
      def inline_keyboard(&)
        self.reply_markup = Keyboard.inline(&)
      end

      def reply_keyboard(**, &)
        self.reply_markup = Keyboard.reply(**, &)
      end

      def remove_keyboard(**)
        self.reply_markup = Keyboard.remove(**)
      end

      def force_reply(**)
        self.reply_markup = Keyboard.force_reply(**)
      end
    end
  end
end
