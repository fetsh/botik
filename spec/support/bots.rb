# frozen_string_literal: true

# Two independent bots used across the specs.

class ShopBot < Botik::Bot
  configure do |config|
    config.token = "111:SHOP"
    config.username = "shop_bot"
  end

  routes do
    command :start, to: "catalog#index"
    callback "items/:id", to: "catalog#show"
    callback "items/:id/buy", to: "catalog#buy"

    scope state: :awaiting_address do
      text to: "checkout#address"
    end

    text(/\Afind (?<query>.+)\z/i, to: "catalog#search")
    message :photo, to: "catalog#photo"
    default to: "catalog#unknown"
  end
end

class ShopBot
  module FormattingHelper
    def price(amount)
      format("%.2f ₪", amount)
    end
  end

  class ApplicationController < Botik::Controller
    helper FormattingHelper
  end

  class CatalogController < ApplicationController
    ITEMS = { "1" => { title: "Tea <green>", price: 12.5 }, "2" => { title: "Coffee_beans*", price: 40 } }.freeze

    def index
      @items = ITEMS
    end

    def show
      @item = ITEMS.fetch(params[:id])
      edit_message template: :show
    end

    def buy
      self.state = :awaiting_address
      answer_callback_query "Added"
      reply "Where should we deliver?"
    end

    def search
      reply "Searching #{params[:query]}"
    end

    def photo
      reply "Nice photo"
    end

    def unknown; end
  end

  class CheckoutController < ApplicationController
    def address
      self.state = nil
      session[:address] = update.text
      render plain: "Delivering to #{update.text}"
    end
  end
end

class SupportBot < Botik::Bot
  configure do |config|
    config.token = "222:SUPPORT"
  end

  routes do
    command :start, to: "tickets#new"
    namespace :admin, if: ->(request) { request.update.user_id == 1 } do
      command :stats, to: "stats#show"
    end
  end
end

class SupportBot
  class ApplicationController < Botik::Controller; end

  class TicketsController < ApplicationController
    def new
      reply "Describe your problem"
    end
  end

  module Admin
    class StatsController < SupportBot::ApplicationController
      def show
        reply "42 tickets"
      end
    end
  end
end
