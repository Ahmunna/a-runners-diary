class Admin::UsersController < ApplicationController
  before_action :require_admin!

  def index
    @users = User.includes(:athlete_profile, :race, :strava_connection).order(:created_at)
  end

  def show
    @user = User.find(params[:id])
    @race = @user.race
    @program = @race&.active_program
    @activities = @user.strava_activities.order(occurred_at: :desc).limit(10)
    @messages = @user.messages.order(created_at: :desc).limit(20)
  end
end
