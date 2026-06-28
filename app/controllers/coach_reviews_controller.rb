class CoachReviewsController < ApplicationController
  def create
    if current_user.claude_credential.blank?
      return redirect_to dashboard_path, alert: "Add your Claude API key first."
    end

    Coach::ReactToActivityJob.perform_later(current_user.id, "Athlete requested a manual plan review.")
    redirect_to dashboard_path, notice: "Asked your coach to review your plan — check back in a moment."
  end
end
