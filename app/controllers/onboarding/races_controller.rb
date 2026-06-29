class Onboarding::RacesController < ApplicationController
  def new
    @race = current_user.race || current_user.build_race
  end

  def create
    @race = current_user.race || current_user.build_race
    was_new_race = @race.new_record?
    had_active_program = @race.active_program.present?
    @race.assign_attributes(race_params)

    if @race.save
      notify_coach(had_active_program)

      if was_new_race
        redirect_to onboarding_app_setup_path, notice: "Goal set."
      else
        redirect_to dashboard_path, notice: "Race updated."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def race_params
    params.require(:race).permit(:race_type, :race_date, :time_objective, :difficulty, :strength_training_frequency)
  end

  def notify_coach(had_active_program)
    return unless current_user.claude_credential

    if had_active_program
      Coach::ReactToActivityJob.perform_later(current_user.id, "Athlete updated their race or training preferences — review and adjust the existing plan accordingly.")
    else
      Coach::GenerateProgramJob.perform_later(current_user.id)
    end
  end
end
