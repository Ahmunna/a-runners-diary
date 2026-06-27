class Onboarding::RacesController < ApplicationController
  def new
    @race = current_user.race || current_user.build_race
  end

  def create
    @race = current_user.race || current_user.build_race
    @race.assign_attributes(race_params)

    if @race.save
      Coach::GenerateProgramJob.perform_later(current_user.id) if current_user.claude_credential
      redirect_to dashboard_path, notice: "Goal set. Connect Strava and add your Claude API key to generate your training program."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def race_params
    params.require(:race).permit(:race_type, :race_date, :time_objective, :difficulty)
  end
end
