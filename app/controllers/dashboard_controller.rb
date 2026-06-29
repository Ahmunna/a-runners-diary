class DashboardController < ApplicationController
  def show
    @race = current_user.race
    @program = @race&.active_program
    @today = @program&.today
    @current_week = @program&.current_week
    @total_weeks = @program&.training_weeks&.count
    @recent_activities = current_user.strava_activities.order(occurred_at: :desc).limit(5)
    @nutrition_log = current_user.nutrition_logs.find_by(date: Date.current)
  end
end
