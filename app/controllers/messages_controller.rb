class MessagesController < ApplicationController
  def index
    @messages = current_user.messages.order(created_at: :asc)
  end

  def create
    Coach::Chat.call(current_user, params.require(:message).permit(:content).fetch(:content))

    if current_user.athlete_profile&.review_on_chat?
      Coach::ReactToActivityJob.perform_later(current_user.id, "Athlete sent a chat message — review the conversation for any plan adjustments.")
    end

    redirect_to messages_path
  rescue ArgumentError => e
    redirect_to messages_path, alert: e.message
  rescue Coach::Client::Error => e
    redirect_to messages_path, alert: "Claude error: #{e.message}"
  end
end
