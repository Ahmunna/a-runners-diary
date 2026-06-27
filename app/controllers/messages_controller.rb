class MessagesController < ApplicationController
  def index
    @messages = current_user.messages.order(created_at: :asc)
  end

  def create
    Coach::Chat.call(current_user, params.require(:message).permit(:content).fetch(:content))
    redirect_to messages_path
  rescue ArgumentError => e
    redirect_to messages_path, alert: e.message
  rescue Coach::Client::Error => e
    redirect_to messages_path, alert: "Claude error: #{e.message}"
  end
end
