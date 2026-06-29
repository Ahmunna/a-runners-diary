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

  def update_summary
    user = User.find(params[:id])
    program = user.race&.active_program

    if program.nil?
      redirect_to admin_user_path(user), alert: "This athlete has no active program to update."
    elsif program.update(claude_summary: params[:claude_summary])
      redirect_to admin_user_path(user), notice: "Summary updated."
    else
      redirect_to admin_user_path(user), alert: program.errors.full_messages.to_sentence
    end
  end

  def send_notification
    user = User.find(params[:id])
    title = params[:title].presence || "A Runner's Diary"
    body = params[:body].to_s

    if PushNotificationService.notify(user, title: title, body: body)
      redirect_to admin_user_path(user), notice: "Notification sent."
    else
      redirect_to admin_user_path(user), alert: "Nothing sent — this athlete has no active notification subscription, or push isn't configured on this server (VAPID keys)."
    end
  end
end
