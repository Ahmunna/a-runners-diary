class StravaSyncsController < ApplicationController
  def create
    unless current_user.strava_connection
      return redirect_to dashboard_path, alert: "Connect Strava first."
    end

    Strava::SyncActivitiesJob.perform_later(current_user.id)
    redirect_to dashboard_path, notice: "Checking Strava and your nutrition logs for anything new — your coach will only weigh in if there's actually something to react to."
  end
end
