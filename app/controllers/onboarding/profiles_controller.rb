class Onboarding::ProfilesController < ApplicationController
  before_action :set_athlete_profile

  def new
  end

  def create
    @athlete_profile.assign_attributes(athlete_profile_params)

    if @athlete_profile.save
      redirect_to new_onboarding_race_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @athlete_profile.update(athlete_profile_params)
      redirect_to edit_onboarding_profile_path, notice: "Profile updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_athlete_profile
    @athlete_profile = current_user.athlete_profile || current_user.build_athlete_profile
  end

  def athlete_profile_params
    params.require(:athlete_profile).permit(:age, :sex, :height_cm, :notes, :timezone, :review_on_chat, :review_on_nutrition_log)
  end
end
