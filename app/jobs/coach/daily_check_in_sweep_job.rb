module Coach
  # Runs every hour (see config/recurring.yml). Because every athlete's local
  # hour advances by exactly one each time this runs, each athlete hits their
  # local 9am exactly once per day — no per-user cron entries needed.
  class DailyCheckInSweepJob < ApplicationJob
    queue_as :default

    CHECK_IN_HOUR = 9

    def perform
      AthleteProfile.joins(user: :race).find_each do |profile|
        next unless profile.user.claude_credential
        next if profile.checked_in_today?
        next unless profile.local_hour_now == CHECK_IN_HOUR

        profile.update!(last_daily_checkin_on: profile.time_zone.today)

        program = profile.user.race.active_program
        next unless program&.review_worthwhile?

        Coach::ReactToActivityJob.perform_later(profile.user_id, "Daily 9am check-in.")
      end
    end
  end
end
