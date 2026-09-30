# frozen_string_literal: true

RSpec.describe Botik::Routing do
  let(:bot) do
    Class.new(Botik::Bot) do
      configure { |c| c.username = "my_bot" }
    end
  end

  def recognize(update)
    request = Botik::Request.new(bot, Botik::Update.parse(update))
    route, params = bot.routes.recognize(request)
    route && [route.endpoint, params]
  end

  it "matches commands, case-insensitively, with args and bot username" do
    bot.routes { command %i[start begin], to: "welcome#start" }

    expect(recognize(telegram_message("/START ref"))).to eq(["welcome#start", { command: "START", args: "ref" }])
    expect(recognize(telegram_message("/begin@my_bot"))).to eq(["welcome#start", { command: "begin", args: "" }])
    expect(recognize(telegram_message("/start@other_bot"))).to be_nil
    expect(recognize(telegram_message("start"))).to be_nil
  end

  it "matches callback data patterns with named segments and splats" do
    bot.routes do
      callback "orders/:id", to: "orders#show"
      callback "vote::choice", to: "votes#create"
      callback "files/*path", to: "files#show"
      callback(/\Apage-(?<n>\d+)\z/, to: "pages#show")
      callback to: "callbacks#any"
    end

    expect(recognize(telegram_callback("orders/7"))).to eq(["orders#show", { data: "orders/7", id: "7" }])
    expect(recognize(telegram_callback("vote:yes"))).to eq(["votes#create", { data: "vote:yes", choice: "yes" }])
    expect(recognize(telegram_callback("files/a/b.txt"))).to eq(["files#show",
                                                                 { data: "files/a/b.txt", path: "a/b.txt" }])
    expect(recognize(telegram_callback("page-3"))).to eq(["pages#show", { data: "page-3", n: "3" }])
    expect(recognize(telegram_callback("orders/7/x")).first).to eq("callbacks#any")
  end

  it "matches text exactly, by regexp or any" do
    bot.routes do
      text "Menu", to: "menu#show"
      text(/\A(\d+)\+(\d+)\z/, to: "calc#add")
      text to: "echo#say"
    end

    expect(recognize(telegram_message("Menu")).first).to eq("menu#show")
    endpoint, params = recognize(telegram_message("2+3"))
    expect(endpoint).to eq("calc#add")
    expect(params[:match].captures).to eq(%w[2 3])
    expect(recognize(telegram_message("menu")).first).to eq("echo#say")
  end

  it "matches message kinds and update types" do
    bot.routes do
      message :photo, :document, to: "media#create"
      on :inline_query, :chosen_inline_result, to: "inline#search"
      message to: "messages#any"
    end

    expect(recognize(telegram_message(document: { file_id: "d" }))).to eq(["media#create", { kind: :document }])
    expect(recognize(telegram_update(:inline_query, id: "1", query: "q")).first).to eq("inline#search")
    expect(recognize(telegram_message(location: { latitude: 1, longitude: 2 })).first).to eq("messages#any")
  end

  it "ignores edited messages unless asked" do
    bot.routes do
      text to: "texts#new"
      text to: "texts#edited", types: :edited_message
    end

    expect(recognize(telegram_message("hi")).first).to eq("texts#new")
    expect(recognize(telegram_message("hi", type: :edited_message)).first).to eq("texts#edited")
  end

  it "applies chat_type, state and if constraints, nested scopes and namespaces" do
    bot.routes do
      scope chat_type: :private do
        scope state: :awaiting_name do
          text to: "signup#name"
        end
        namespace :admin, if: ->(request) { request.update.user_id == 1 } do
          namespace :reports, if: ->(request) { request.update.text != "/daily nope" } do
            command :daily, to: "daily#show"
          end
        end
      end
      default to: "fallback#show", unless: ->(request) { request.update.type == :poll }
    end

    expect(recognize(telegram_message("/daily", from: { id: 1 })).first).to eq("admin/reports/daily#show")
    expect(recognize(telegram_message("/daily nope", from: { id: 1 })).first).to eq("fallback#show")
    expect(recognize(telegram_message("/daily", from: { id: 2 })).first).to eq("fallback#show")
    expect(recognize(telegram_message("/daily", from: { id: 1 }, chat: { type: "group" })).first)
      .to eq("fallback#show")
    expect(recognize(telegram_update(:poll, id: "p"))).to be_nil

    update = telegram_message("Ann")
    request = Botik::Request.new(bot, Botik::Update.parse(update))
    request.session[:state] = "awaiting_name"
    expect(bot.routes.recognize(request).first.endpoint).to eq("signup#name")
  end

  it "validates route definitions" do
    expect { bot.routes { command :start, to: "welcome" } }.to raise_error(Botik::RoutingError)
    expect { bot.routes { command :start, to: "a#b", only: :x } }.to raise_error(ArgumentError, /only/)
  end

  it "prints routes" do
    bot.routes do
      command :start, to: "welcome#start", chat_type: :private
      on :poll, to: ->(_request) {}
    end

    expect(bot.routes.to_s).to eq(<<~ROUTES.strip)
      command  /start                   => welcome#start chat_type: private
      on       poll                     => <proc>
    ROUTES
  end

  it "resolves controllers in the bot namespace at dispatch time" do
    route = ShopBot.routes.first
    expect(route.controller_class(ShopBot)).to eq(ShopBot::CatalogController)

    missing = Botik::Routing::Route.new(kind: :default, matcher: Botik::Routing::Matchers::Any.new, endpoint: "nope#x")
    expect { missing.controller_class(ShopBot) }.to raise_error(Botik::RoutingError, /ShopBot::NopeController/)
  end
end
