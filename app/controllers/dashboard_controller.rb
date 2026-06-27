class DashboardController < ApplicationController
  def show
    @race = current_user.race
    @program = @race&.active_program
    @today = @program&.today
    @recent_activities = current_user.strava_activities.order(occurred_at: :desc).limit(5)
    @nutrition_log = current_user.nutrition_logs.find_by(date: Date.current)
  end
end
