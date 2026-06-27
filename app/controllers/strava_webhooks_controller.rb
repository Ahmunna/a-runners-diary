class StravaWebhooksController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :redirect_to_onboarding_if_needed
  skip_before_action :verify_authenticity_token

  # Strava's subscription handshake: GET with hub.mode/hub.challenge/hub.verify_token.
  def create
    if request.get? || request.head?
      return handle_handshake
    end

    handle_event
    head :ok
  end

  private

  def handle_handshake
    if params["hub.verify_token"] == ENV.fetch("STRAVA_WEBHOOK_VERIFY_TOKEN")
      render json: { "hub.challenge" => params["hub.challenge"] }
    else
      head :forbidden
    end
  end

  def handle_event
    return unless params[:object_type] == "activity" && params[:aspect_type].in?(%w[create update])

    Strava::ProcessActivityJob.perform_later(params[:owner_id], params[:object_id])
  end
end
