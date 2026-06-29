class ClaudeCredentialsController < ApplicationController
  # Only enforced on first setup (new/create) — once an athlete has a key,
  # editing/replacing it shouldn't suddenly lock them out just because
  # they later disconnected Strava.
  before_action :require_strava_connection, only: [ :new, :create ]

  def new
    @claude_credential = current_user.claude_credential || current_user.build_claude_credential
  end

  def create
    @claude_credential = current_user.claude_credential || current_user.build_claude_credential
    @claude_credential.assign_attributes(claude_credential_params)

    if @claude_credential.save
      enqueue_program_generation_if_ready
      redirect_to dashboard_path, notice: "Claude API key saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @claude_credential = current_user.claude_credential || current_user.build_claude_credential
  end

  def update
    @claude_credential = current_user.claude_credential || current_user.build_claude_credential
    @claude_credential.assign_attributes(claude_credential_params)

    if @claude_credential.save
      enqueue_program_generation_if_ready
      redirect_to dashboard_path, notice: "Claude API key updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_strava_connection
    return if current_user.strava_connection.present? || current_user.claude_credential.present?

    redirect_to dashboard_path, alert: "Connect Strava first, so your coach starts with your real training history."
  end

  def claude_credential_params
    params.require(:claude_credential).permit(:api_key)
  end

  def enqueue_program_generation_if_ready
    return unless current_user.race && current_user.race.active_program.nil?

    Coach::GenerateProgramJob.perform_later(current_user.id)
  end
end
