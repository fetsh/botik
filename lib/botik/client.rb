# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "securerandom"

module Botik
  # A thin Telegram Bot API client.
  #
  # Every Bot API method is available in snake_case; parameters are passed as keywords.
  # Results come back wrapped in Botik::Payload:
  #
  #   client = Botik::Client.new(ENV["TOKEN"])
  #   client.get_me.username                             # => "my_bot"
  #   client.send_message(chat_id: 1, text: "Hello")     # => #<Botik::Payload ...>
  #   client.send_photo(chat_id: 1, photo: File.open("cat.jpg"))
  #   client.call("sendMessage", chat_id: 1, text: "Hi") # the explicit form
  #
  # Files (anything that responds to +read+) switch the request to multipart/form-data.
  # Nested hashes and arrays (e.g. +reply_markup+) are JSON-encoded automatically.
  class Client
    DEFAULT_API_URL = "https://api.telegram.org"

    NETWORK_ERRORS = [
      IOError, EOFError, SocketError, SystemCallError, Timeout::Error,
      OpenSSL::SSL::SSLError, Net::HTTPBadResponse
    ].freeze

    attr_reader :token, :api_url, :timeout, :open_timeout

    def initialize(token, api_url: DEFAULT_API_URL, timeout: 30, open_timeout: 10)
      raise ConfigurationError, "Telegram bot token is not set" if token.nil? || token.to_s.empty?

      @token = token
      @api_url = api_url.to_s.chomp("/")
      @timeout = timeout
      @open_timeout = open_timeout
    end

    # Calls a Bot API method. +api_method+ may be camelCase or snake_case.
    def call(api_method, params = {})
      api_method = camelize(api_method.to_s)
      params = compact(params)

      ActiveSupport::Notifications.instrument("api_call.botik", api_method: api_method, params: params) do
        body = perform(api_method, params)
        raise ApiError.from_response(api_method, body) unless body["ok"]

        Payload.wrap(body["result"])
      end
    end

    def inspect
      "#<#{self.class.name} bot_id=#{token.to_s.split(':').first}>"
    end

    private

    def perform(api_method, params)
      uri = URI("#{api_url}/bot#{token}/#{api_method}")
      request = build_request(uri, params)
      read_timeout = timeout
      read_timeout += params[:timeout].to_i if api_method == "getUpdates"

      response = Net::HTTP.start(
        uri.host, uri.port,
        use_ssl: uri.scheme == "https", open_timeout: open_timeout, read_timeout: read_timeout
      ) { |http| http.request(request) }

      JSON.parse(response.body)
    rescue JSON::ParserError
      raise NetworkError, "#{api_method}: unexpected response #{response&.code} #{response&.body.to_s[0, 200]}"
    rescue *NETWORK_ERRORS => e
      raise NetworkError, "#{api_method}: #{e.class}: #{e.message}"
    end

    def build_request(uri, params)
      request = Net::HTTP::Post.new(uri)
      if params.values.any? { |value| file?(value) }
        boundary = "botik-#{SecureRandom.hex(16)}"
        request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
        request.body = multipart_body(params, boundary)
      else
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(params)
      end
      request
    end

    def multipart_body(params, boundary)
      body = params.map do |key, value|
        part = "--#{boundary}\r\n"
        if file?(value)
          filename = value.respond_to?(:path) && value.path ? File.basename(value.path) : key.to_s
          part << %(Content-Disposition: form-data; name="#{key}"; filename="#{filename}"\r\n)
          part << "Content-Type: application/octet-stream\r\n\r\n"
          part << value.read.b
        else
          value = JSON.generate(value) if value.is_a?(Hash) || value.is_a?(Array)
          part << %(Content-Disposition: form-data; name="#{key}"\r\n\r\n)
          part << value.to_s
        end
        part.b << "\r\n"
      end
      body.join.b + "--#{boundary}--\r\n"
    end

    def file?(value)
      value.respond_to?(:read)
    end

    def compact(params)
      params.to_h.transform_keys(&:to_sym).compact
    end

    def camelize(name)
      name.gsub(/_([a-z])/) { Regexp.last_match(1).upcase }
    end

    def method_missing(name, params = nil, **kwargs)
      return super unless api_method_name?(name)

      call(name, (params || {}).merge(kwargs))
    end

    def respond_to_missing?(name, include_private = false)
      api_method_name?(name) || super
    end

    def api_method_name?(name)
      name.to_s.match?(/\A[a-z][a-z0-9_]*\z/) && !name.to_s.start_with?("to_")
    end
  end
end
