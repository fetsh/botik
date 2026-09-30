# frozen_string_literal: true

module Botik
  # Base class for every error raised by Botik.
  class Error < StandardError; end

  # A route points to a controller that cannot be found, or the route is malformed.
  class RoutingError < Error; end

  # A route points to an action the controller does not define.
  class ActionNotFound < Error; end

  # +render+ was asked for a template that does not exist in any view path.
  class TemplateMissing < Error; end

  # The bot is missing required configuration (e.g. a token).
  class ConfigurationError < Error; end

  # The Telegram API could not be reached (timeouts, connection errors, bad JSON).
  class NetworkError < Error; end

  # The Telegram API responded with <tt>ok: false</tt>.
  #
  # Specific subclasses are raised for the most common error codes so they can be
  # rescued individually:
  #
  #   rescue_from Botik::ApiError::Forbidden do
  #     # the user blocked the bot
  #   end
  class ApiError < Error
    attr_reader :api_method, :error_code, :description, :parameters

    def initialize(api_method:, error_code:, description:, parameters: nil)
      @api_method = api_method
      @error_code = error_code
      @description = description
      @parameters = parameters || {}
      super("#{api_method} failed (#{error_code}): #{description}")
    end

    # Seconds to wait before retrying, sent with 429 responses.
    def retry_after
      parameters["retry_after"]
    end

    class BadRequest < ApiError; end
    class Unauthorized < ApiError; end
    class Forbidden < ApiError; end
    class NotFound < ApiError; end
    class Conflict < ApiError; end
    class TooManyRequests < ApiError; end

    CLASSES = {
      400 => BadRequest,
      401 => Unauthorized,
      403 => Forbidden,
      404 => NotFound,
      409 => Conflict,
      429 => TooManyRequests
    }.freeze

    # Builds the right subclass from a decoded API response body.
    def self.from_response(api_method, body)
      klass = CLASSES.fetch(body["error_code"], ApiError)
      klass.new(
        api_method: api_method,
        error_code: body["error_code"],
        description: body["description"],
        parameters: body["parameters"]
      )
    end
  end
end
