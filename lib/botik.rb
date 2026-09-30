# frozen_string_literal: true

require "json"
require "openssl"
require "active_support"
require "active_support/callbacks"
require "active_support/concern"
require "active_support/rescuable"
require "active_support/notifications"
require "active_support/security_utils"
require "active_support/hash_with_indifferent_access"
require "active_support/core_ext/class/attribute"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/string/inflections"

require_relative "botik/version"
require_relative "botik/errors"
require_relative "botik/payload"
require_relative "botik/update"
require_relative "botik/client"
require_relative "botik/session_store/memory"
require_relative "botik/configuration"
require_relative "botik/session"
require_relative "botik/request"
require_relative "botik/keyboard"
require_relative "botik/routing/matchers"
require_relative "botik/routing/route"
require_relative "botik/routing/mapper"
require_relative "botik/routing/route_set"
require_relative "botik/view/formats"
require_relative "botik/view/template"
require_relative "botik/view/helpers"
require_relative "botik/view/context"
require_relative "botik/controller/callbacks"
require_relative "botik/controller/rendering"
require_relative "botik/controller/messaging"
require_relative "botik/controller"
require_relative "botik/middleware_stack"
require_relative "botik/bot"
require_relative "botik/webhook"
require_relative "botik/poller"

# Rails-style framework for Telegram bots. See README.md.
module Botik
  class << self
    # Global defaults every bot's configuration falls back to.
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    # Named Botik::Bot subclasses that have been loaded, in definition order.
    # In Rails, bots in app/bots are known once the app is eager loaded.
    def bots
      bot_names.filter_map(&:safe_constantize).select { |bot| bot.is_a?(Class) && bot < Bot }
    end

    def bot_names # :nodoc:
      @bot_names ||= []
    end
  end
end

require_relative "botik/railtie" if defined?(Rails::Railtie)
