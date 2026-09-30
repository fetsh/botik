# frozen_string_literal: true

module Botik
  module SessionStore
    # Thread-safe in-process session store. Good for development, tests and
    # single-process bots; sessions are lost on restart. Use Rails.cache or any
    # other object with the same read/write/delete interface in production.
    class Memory
      def initialize(expires_in: nil)
        @expires_in = expires_in
        @data = {}
        @mutex = Mutex.new
      end

      def read(key)
        @mutex.synchronize do
          value, expires_at = @data[key]
          if expires_at && expires_at <= now
            @data.delete(key)
            return nil
          end
          value && Marshal.load(value) # rubocop:disable Security/MarshalLoad -- data we dumped ourselves
        end
      end

      def write(key, value, expires_in: @expires_in)
        @mutex.synchronize do
          @data[key] = [Marshal.dump(value), expires_in && (now + expires_in)]
        end
        true
      end

      def delete(key)
        @mutex.synchronize { !@data.delete(key).nil? }
      end

      def clear
        @mutex.synchronize { @data.clear }
      end

      private

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
