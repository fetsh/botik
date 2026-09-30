# frozen_string_literal: true

require "cgi"

module Botik
  module View
    # A String that must not be escaped again (the result of +raw+, formatting
    # helpers and partials).
    class SafeString < String
      def to_s
        self
      end
    end

    # A template's format is taken from its file name (+show.html.erb+,
    # +show.md.erb+, +show.text.erb+). It defines the Telegram parse_mode, how
    # <tt><%= %></tt> output is escaped and what the formatting helpers produce.
    module Formats
      # Plain text: no parse_mode, no escaping, formatting helpers return the text as is.
      class Text
        def self.parse_mode = nil

        def self.escape(text) = text.to_s

        def self.escape_code(text) = text.to_s

        def self.bold(text) = text
        def self.italic(text) = text
        def self.underline(text) = text
        def self.strike(text) = text
        def self.spoiler(text) = text
        def self.code(text) = text
        def self.pre(text, _language = nil) = text
        def self.quote(text) = text

        def self.link(text, url)
          "#{text} (#{url})"
        end
      end

      # Telegram HTML.
      class Html
        def self.parse_mode = "HTML"

        def self.escape(text) = CGI.escapeHTML(text.to_s)

        def self.escape_code(text) = escape(text)

        def self.bold(text) = "<b>#{text}</b>"
        def self.italic(text) = "<i>#{text}</i>"
        def self.underline(text) = "<u>#{text}</u>"
        def self.strike(text) = "<s>#{text}</s>"
        def self.spoiler(text) = "<tg-spoiler>#{text}</tg-spoiler>"
        def self.code(text) = "<code>#{text}</code>"
        def self.quote(text) = "<blockquote>#{text}</blockquote>"

        def self.pre(text, language = nil)
          return "<pre>#{text}</pre>" unless language

          %(<pre><code class="language-#{escape(language)}">#{text}</code></pre>)
        end

        def self.link(text, url)
          %(<a href="#{escape(url)}">#{text}</a>)
        end
      end

      # Telegram MarkdownV2.
      class Markdown
        SPECIAL = /[_*\[\]()~`>#+\-=|{}.!\\]/

        def self.parse_mode = "MarkdownV2"

        def self.escape(text) = text.to_s.gsub(SPECIAL) { |char| "\\#{char}" }

        def self.bold(text) = "*#{text}*"
        def self.italic(text) = "_#{text}_"
        def self.underline(text) = "__#{text}__"
        def self.strike(text) = "~#{text}~"
        def self.spoiler(text) = "||#{text}||"
        def self.quote(text) = text.to_s.lines.map { |line| ">#{line}" }.join

        # Code spans only escape ` and \ inside.
        def self.code(text) = "`#{text}`"

        def self.pre(text, language = nil)
          "```#{language}\n#{text}\n```"
        end

        def self.link(text, url)
          "[#{text}](#{url.to_s.gsub(/[)\\]/) { |char| "\\#{char}" }})"
        end

        def self.escape_code(text) = text.to_s.gsub(/[`\\]/) { |char| "\\#{char}" }
      end

      EXTENSIONS = {
        "html" => Html,
        "md" => Markdown,
        "markdown" => Markdown,
        "text" => Text,
        "txt" => Text
      }.freeze

      def self.for(extension)
        EXTENSIONS.fetch(extension.to_s) { raise ArgumentError, "unknown template format #{extension.inspect}" }
      end
    end
  end
end
