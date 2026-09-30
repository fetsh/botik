# frozen_string_literal: true

module Botik
  # A read-only, method-accessible view of a Telegram JSON object.
  #
  # Botik does not model the Telegram schema with classes: the Bot API grows every
  # few months and hand-written types go stale. Instead every object is wrapped in a
  # Payload, which exposes its fields as methods:
  #
  #   message = Botik::Payload.new("chat" => { "id" => 1 }, "text" => "hi")
  #   message.chat.id    # => 1
  #   message.text       # => "hi"
  #   message.text?      # => true
  #   message.photo      # => nil (absent optional fields are nil)
  #   message[:text]     # => "hi"
  class Payload
    # Wraps hashes (recursively, lazily) and arrays of hashes; returns anything else as is.
    def self.wrap(value)
      case value
      when Hash then new(value)
      when Array then value.map { |item| wrap(item) }
      else value
      end
    end

    def initialize(hash = {})
      @hash = hash.transform_keys(&:to_s)
      @wrapped = {}
    end

    def [](key)
      key = key.to_s
      return @wrapped[key] if @wrapped.key?(key)

      @wrapped[key] = Payload.wrap(@hash[key])
    end

    def key?(key)
      @hash.key?(key.to_s)
    end
    alias has_key? key?

    def keys
      @hash.keys
    end

    def dig(key, *rest)
      value = self[key]
      rest.empty? || value.nil? ? value : value.dig(*rest)
    end

    def fetch(key, *default, &)
      return self[key] if key?(key)

      @hash.fetch(key.to_s, *default, &)
    end

    # The underlying data as a plain Hash with string keys (safe to serialize to JSON).
    def to_h
      deep_unwrap(@hash)
    end
    alias to_hash to_h

    def to_json(*)
      to_h.to_json(*)
    end

    def ==(other)
      to_h == (other.is_a?(Payload) ? other.to_h : other)
    end
    alias eql? ==

    def hash
      to_h.hash
    end

    def inspect
      "#<#{self.class.name} #{@hash.inspect}>"
    end

    private

    def deep_unwrap(value)
      case value
      when Payload then value.to_h
      when Hash then value.to_h { |k, v| [k.to_s, deep_unwrap(v)] }
      when Array then value.map { |item| deep_unwrap(item) }
      else value
      end
    end

    def method_missing(name, *args)
      name = name.to_s
      return super unless args.empty? && field_name?(name)

      if name.end_with?("?")
        value = self[name.chomp("?")]
        !(value.nil? || value == false || (value.respond_to?(:empty?) && value.empty?))
      else
        self[name]
      end
    end

    def respond_to_missing?(name, include_private = false)
      field_name?(name.to_s) || super
    end

    # Conversion methods (to_str, to_ary, ...) must not be answered by method_missing,
    # otherwise Ruby would treat every payload as a String/Array.
    def field_name?(name)
      name.match?(/\A[a-z][a-z0-9_]*\??\z/) && !name.start_with?("to_")
    end
  end
end
