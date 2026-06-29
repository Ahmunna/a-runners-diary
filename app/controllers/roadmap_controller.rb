class RoadmapController < ApplicationController
  def show
    @race = current_user.race
    @program = @race&.active_program
    @weeks = @program&.training_weeks&.ordered || TrainingWeek.none
  end
end
