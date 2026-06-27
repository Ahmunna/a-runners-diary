class Onboarding::ProfilesController < ApplicationController
  def new
    @athlete_profile = current_user.athlete_profile || current_user.build_athlete_profile
  end

  def create
    @athlete_profile = current_user.athlete_profile || current_user.build_athlete_profile
    @athlete_profile.assign_attributes(athlete_profile_params)

    if @athlete_profile.save
      redirect_to new_onboarding_race_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def athlete_profile_params
    params.require(:athlete_profile).permit(:age, :sex, :height_cm, :notes)
  end
end
