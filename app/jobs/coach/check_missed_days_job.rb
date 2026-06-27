module Coach
  # Scheduled daily (see config/recurring.yml). Marks past-due pending
  # training days as skipped and asks Claude to re-adapt for each affected
  # athlete.
  class CheckMissedDaysJob < ApplicationJob
    queue_as :default

    def perform
      TrainingDay.past_due.includes(training_program: :race).find_each do |day|
        day.update!(status: "skipped")
        user = day.training_program.race.user
        Coach::ReactToActivityJob.perform_later(user.id, "Training day #{day.date} (#{day.workout}) passed with no matching activity — it was skipped.")
      end
    end
  end
end
