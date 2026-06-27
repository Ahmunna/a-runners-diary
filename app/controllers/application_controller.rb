class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :authenticate_user!
  before_action :redirect_to_onboarding_if_needed

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name ])
  end

  def require_admin!
    redirect_to root_path, alert: "Not authorized." unless current_user&.admin?
  end

  private

  def redirect_to_onboarding_if_needed
    return unless user_signed_in?
    return if current_user.admin?
    return if controller_path.start_with?("onboarding") || controller_path == "devise/sessions"

    if current_user.athlete_profile.blank?
      redirect_to new_onboarding_profile_path unless controller_path == "onboarding/profiles"
    elsif current_user.race.blank?
      redirect_to new_onboarding_race_path unless controller_path == "onboarding/races"
    end
  end
end
