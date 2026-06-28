class StravaConnectionsController < ApplicationController
  def connect
    state = SecureRandom.hex(16)
    session[:strava_oauth_state] = state
    redirect_to Strava::Client.authorize_url(strava_callback_url, state: state), allow_other_host: true
  end

  def callback
    if params[:state] != session.delete(:strava_oauth_state)
      return redirect_to dashboard_path, alert: "Strava connection failed (invalid state)."
    end

    if params[:error].present?
      return redirect_to dashboard_path, alert: "Strava authorization was denied."
    end

    data = Strava::Client.exchange_code(params[:code])

    current_user.strava_connection&.destroy
    current_user.create_strava_connection!(
      strava_athlete_id: data.dig("athlete", "id"),
      access_token: data["access_token"],
      refresh_token: data["refresh_token"],
      expires_at: Time.at(data["expires_at"])
    )

    Strava::SyncActivitiesJob.perform_later(current_user.id)
    redirect_to dashboard_path, notice: "Strava connected — pulling in your recent activity history now."
  rescue Strava::Client::Error => e
    redirect_to dashboard_path, alert: "Strava connection failed: #{e.message}"
  end

  def destroy
    current_user.strava_connection&.destroy
    redirect_to dashboard_path, notice: "Strava disconnected."
  end
end
