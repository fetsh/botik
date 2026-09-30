# frozen_string_literal: true

module Botik
  module Testing
    # Drop-in replacement for Botik::Client that records calls instead of
    # talking to Telegram.
    #
    #   api = Botik::Testing::FakeClient.new
    #   api.stub(:get_chat, { "id" => 1, "type" => "private" })
    #   api.stub(:send_message) { |params| raise Botik::ApiError::Forbidden.new(...) }
    #
    #   api.calls                 # => [#<data Call api_method=:send_message, params={...}>]
    #   api.calls(:send_message)
    #   api.sent_messages         # => [{chat_id: 1, text: "Hi"}]
    class FakeClient
      Call = Data.define(:api_method, :params)

      attr_reader :token

      def initialize(token = "123456:TEST")
        @token = token
        @calls = []
        @stubs = {}
        @message_id = 0
      end

      def call(api_method, params = {})
        api_method = api_method.to_s.underscore.to_sym
        params = params.to_h.transform_keys(&:to_sym).compact
        @calls << Call.new(api_method, params)

        stub = @stubs[api_method]
        result = if stub.respond_to?(:call) then stub.call(params)
                 elsif @stubs.key?(api_method) then stub
                 else default_result(api_method, params)
                 end
        Payload.wrap(result)
      end

      # Stubs the result of an API method with a value or a block receiving params.
      def stub(api_method, result = nil, &block)
        @stubs[api_method.to_s.underscore.to_sym] = block || result
        self
      end

      def calls(api_method = nil)
        return @calls.dup unless api_method

        name = api_method.to_s.underscore.to_sym
        @calls.select { |call| call.api_method == name }
      end

      def last_call
        @calls.last
      end

      # Params of every sendMessage call.
      def sent_messages
        calls(:send_message).map(&:params)
      end

      def reset!
        @calls.clear
        @stubs.clear
        self
      end

      private

      def default_result(api_method, params)
        case api_method
        when :get_me then { "id" => 1, "is_bot" => true, "first_name" => "Test", "username" => "test_bot" }
        when :get_updates then []
        when /\Asend_/, :edit_message_text, :edit_message_caption, :edit_message_media, :copy_message
          message_result(params)
        else true
        end
      end

      def message_result(params)
        @message_id += 1
        {
          "message_id" => @message_id,
          "date" => Time.now.to_i,
          "chat" => { "id" => params[:chat_id] },
          "text" => params[:text]
        }.compact
      end

      def method_missing(name, params = nil, **kwargs)
        return super unless name.to_s.match?(/\A[a-z][a-z0-9_]*\z/) && !name.to_s.start_with?("to_")

        call(name, (params || {}).merge(kwargs))
      end

      def respond_to_missing?(name, include_private = false)
        (name.to_s.match?(/\A[a-z][a-z0-9_]*\z/) && !name.to_s.start_with?("to_")) || super
      end
    end
  end
end
