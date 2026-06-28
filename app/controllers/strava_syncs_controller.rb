class StravaSyncsController < ApplicationController
  def create
    unless current_user.strava_connection
      return redirect_to dashboard_path, alert: "Connect Strava first."
    end

    Strava::SyncActivitiesJob.perform_later(current_user.id)
    redirect_to dashboard_path, notice: "Syncing your recent Strava activities — refresh in a moment."
  end
end
