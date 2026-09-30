# frozen_string_literal: true

module Botik
  # Base class for bot controllers.
  #
  # A route such as <tt>command :start, to: "welcome#start"</tt> in SupportBot
  # instantiates SupportBot::WelcomeController for the update and calls its
  # +start+ action:
  #
  #   module SupportBot
  #     class ApplicationController < Botik::Controller
  #       before_action :load_user
  #       rescue_from Botik::ApiError::Forbidden, with: :user_blocked_bot
  #
  #       private
  #
  #       def load_user
  #         @user = User.find_or_create_by!(telegram_id: from.id)
  #       end
  #     end
  #
  #     class WelcomeController < ApplicationController
  #       def start
  #         @ref = params[:args]
  #         # nothing sent explicitly => app/views/support_bot/welcome/start.*.erb is rendered
  #       end
  #     end
  #   end
  #
  # Actions are public methods defined in subclasses. After an action has run,
  # if it did not respond and a template for it exists, the template is rendered
  # and sent (implicit rendering). Callback queries that were not answered are
  # answered automatically (see Configuration#auto_answer_callback_queries).
  class Controller
    include ActiveSupport::Callbacks
    include ActiveSupport::Rescuable
    include Callbacks
    include Rendering
    include Messaging

    class << self
      # Instantiates the controller and runs +action+ for the request.
      def dispatch(action, request)
        new(request).process(action)
      end

      # Path used for view lookup: SupportBot::Admin::UsersController => "support_bot/admin/users".
      def controller_path
        @controller_path ||= name.delete_suffix("Controller").underscore
      end

      # "users" for Admin::UsersController.
      def controller_name
        @controller_name ||= name.demodulize.delete_suffix("Controller").underscore
      end

      # Public methods of this controller and its ancestors up to (excluding) Botik::Controller.
      def action_methods
        (public_instance_methods(true) - Controller.public_instance_methods(true)).map(&:to_s)
      end
    end

    delegate :bot, :update, :params, :session, :logger, to: :request

    def initialize(request)
      @_request = request
    end

    def request
      @_request
    end

    def action_name
      @_action_name
    end

    # Runs the action with callbacks, rescue_from handlers, implicit rendering
    # and auto-answering of callback queries. Returns the controller.
    def process(action)
      @_action_name = action.to_s
      unless self.class.action_methods.include?(action_name)
        raise ActionNotFound, "#{self.class.name}##{action_name} is not a public action"
      end

      begin
        run_callbacks(:process_action) do
          public_send(action_name)
          render if !performed? && template_exists?
        end
      rescue StandardError => e
        rescue_with_handler(e) || raise
      end
      auto_answer_callback_query
      self
    end

    # The Telegram API client of the current bot.
    def api
      bot.client
    end

    def chat
      update.chat
    end

    # The user who sent the update.
    def from
      update.from
    end

    # The message of the update (for callback queries, the message with the button).
    def effective_message
      update.effective_message
    end

    def callback_query
      update.object if update.callback_query?
    end

    # Conversation state stored in the session and matched by +state:+ route
    # constraints:
    #
    #   self.state = :awaiting_email   # next text message goes to the state: :awaiting_email routes
    #   self.state = nil               # back to normal routing
    def state
      session["state"]&.to_sym
    end

    def state=(value)
      value.nil? ? session.delete("state") : session["state"] = value.to_s
    end

    private

    def auto_answer_callback_query
      return unless update.callback_query? && !@_callback_answered
      return unless bot.config.auto_answer_callback_queries

      @_callback_answered = true
      api.answer_callback_query(callback_query_id: update.object.id)
    rescue ApiError => e
      logger.warn("[botik] could not answer callback query: #{e.message}")
    end
  end
end
