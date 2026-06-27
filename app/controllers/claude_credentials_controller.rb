class ClaudeCredentialsController < ApplicationController
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

  def claude_credential_params
    params.require(:claude_credential).permit(:api_key)
  end

  def enqueue_program_generation_if_ready
    return unless current_user.race && current_user.race.active_program.nil?

    Coach::GenerateProgramJob.perform_later(current_user.id)
  end
end
