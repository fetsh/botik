# frozen_string_literal: true

module Botik
  # Per-conversation state that survives between updates.
  #
  # By default there is one session per (chat, user) pair. It is loaded lazily the
  # first time it is touched and written back to the store after the update has
  # been processed, only if it changed. Keys are strings; symbols are converted.
  # Values should be simple (strings, numbers, arrays, hashes) so any store can
  # serialize them.
  #
  #   session[:step] = "awaiting_email"
  #   session[:step]   # => "awaiting_email"
  #   session.delete(:step)
  class Session
    attr_reader :key

    # +key+ may be nil for updates without a chat or user; such a session works
    # but is never persisted.
    def initialize(store, key)
      @store = store
      @key = key
      @loaded = false
    end

    def [](name)
      data[name.to_s]
    end

    def []=(name, value)
      data[name.to_s] = value
    end

    def fetch(name, ...)
      data.fetch(name.to_s, ...)
    end

    def key?(name)
      data.key?(name.to_s)
    end

    def delete(name)
      data.delete(name.to_s)
    end

    def update(hash)
      hash.each { |name, value| self[name] = value }
      self
    end

    def clear
      data.clear
      self
    end

    def empty?
      data.empty?
    end

    def to_h
      data.dup
    end

    def loaded?
      @loaded
    end

    # Writes the session back to the store if it was loaded and changed.
    def commit
      return unless loaded? && key && data != @original

      data.empty? ? @store.delete(key) : @store.write(key, data)
      @original = deep_dup(data)
    end

    def inspect
      "#<#{self.class.name} key=#{key.inspect} data=#{loaded? ? data.inspect : '(not loaded)'}>"
    end

    private

    def data
      load unless @loaded
      @data
    end

    def load
      @data = (key && @store.read(key)) || {}
      @data = @data.transform_keys(&:to_s)
      @original = deep_dup(@data)
      @loaded = true
    end

    def deep_dup(value)
      Marshal.load(Marshal.dump(value))
    end
  end
end
