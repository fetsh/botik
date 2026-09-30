# frozen_string_literal: true

# Tasks for managing bots. In Rails they are loaded automatically; elsewhere
# add `load "botik/tasks.rake"` to your Rakefile and define an :environment
# task that loads your bots.
#
# BOT selects the bot class; when omitted, tasks act on every loaded bot
# (routes) or on the only one.

namespace :botik do
  select_bots = lambda do
    Rails.application.eager_load! if defined?(Rails.application) && Rails.application
    if ENV["BOT"]
      [ENV["BOT"].constantize]
    else
      Botik.bots.presence || abort("No bots loaded. Pass BOT=YourBot.")
    end
  end

  select_bot = lambda do
    bots = select_bots.call
    abort("Several bots loaded (#{bots.map(&:name).join(', ')}). Pass BOT=YourBot.") if bots.size > 1
    bots.first
  end

  desc "Print the routes of every bot (or BOT)"
  task routes: :environment do
    select_bots.call.each do |bot|
      puts "#{bot.name}:"
      puts bot.routes.to_s.gsub(/^/, "  ")
      puts
    end
  end

  desc "Process updates with long polling (BOT=YourBot)"
  task poll: :environment do
    select_bot.call.poll(delete_webhook: ENV["DELETE_WEBHOOK"] == "1")
  end

  namespace :webhook do
    desc "Register the webhook (BOT=YourBot URL=https://example.com/telegram/your)"
    task set: :environment do
      url = ENV.fetch("URL") { abort("Pass URL=https://...") }
      bot = select_bot.call
      bot.set_webhook(url, drop_pending_updates: ENV["DROP_PENDING"] == "1")
      puts "#{bot.name}: webhook set to #{url}"
    end

    desc "Remove the webhook (BOT=YourBot)"
    task delete: :environment do
      bot = select_bot.call
      bot.delete_webhook
      puts "#{bot.name}: webhook deleted"
    end

    desc "Show webhook info (BOT=YourBot)"
    task info: :environment do
      bot = select_bot.call
      puts JSON.pretty_generate(bot.client.get_webhook_info.to_h)
    end
  end
end
