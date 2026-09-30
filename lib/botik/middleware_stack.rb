# frozen_string_literal: true

module Botik
  # Rack-style middleware around update processing. A middleware is a class whose
  # instances wrap the next app and receive a Botik::Request:
  #
  #   class IgnoreBots
  #     def initialize(app) = @app = app
  #
  #     def call(request)
  #       return if request.update.from&.is_bot
  #
  #       @app.call(request)
  #     end
  #   end
  #
  #   class SupportBot < Botik::Bot
  #     use IgnoreBots
  #   end
  class MiddlewareStack
    Middleware = Data.define(:klass, :args, :kwargs, :block) do
      def build(app)
        klass.new(app, *args, **kwargs, &block)
      end
    end

    include Enumerable

    def initialize(middlewares = [])
      @middlewares = middlewares.dup
    end

    def initialize_copy(other)
      super
      @middlewares = other.to_a.dup
    end

    def use(klass, *args, **kwargs, &block)
      @middlewares << Middleware.new(klass, args, kwargs, block)
      self
    end

    def insert_before(existing, klass, *args, **kwargs, &block)
      index = @middlewares.index { |middleware| middleware.klass == existing } ||
              raise(ArgumentError, "#{existing} is not in the middleware stack")
      @middlewares.insert(index, Middleware.new(klass, args, kwargs, block))
      self
    end

    def delete(klass)
      @middlewares.reject! { |middleware| middleware.klass == klass }
      self
    end

    def each(&)
      @middlewares.each(&)
    end

    # Builds the chain around +endpoint+ (the router).
    def build(endpoint)
      @middlewares.reverse.inject(endpoint) { |app, middleware| middleware.build(app) }
    end
  end
end
