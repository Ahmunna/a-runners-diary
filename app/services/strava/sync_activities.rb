module Strava
  # Pulls the athlete's most recent Strava activities and stores anything
  # not already synced via webhook. Used both right after connecting Strava
  # (one-time backfill) and from the dashboard's manual "Check for updates"
  # button (catch-up if a webhook event was ever missed).
  #
  # Only triggers a Coach review if there's actually something worth
  # reviewing (new activity, new nutrition logs, or the schedule running
  # low) — calling Claude "just because" produces a low-value summary that
  # overwrites a perfectly good existing one. And when it does trigger,
  # it's always a single consolidated review, never one per activity — a
  # backfill can pull in many activities at once, and reacting to each
  # individually would multiply Claude cost and could fire a flurry of
  # push notifications for old history.
  class SyncActivities
    PER_PAGE = 30

    def self.call(user) = new(user).call

    def initialize(user)
      @user = user
    end

    def call
      new_activity_count = sync_strava_activities
      program = user.race&.active_program

      if program&.review_worthwhile?
        Coach::ReactToActivityJob.perform_later(user.id, review_description(new_activity_count, program))
      end

      new_activity_count
    end

    private

    attr_reader :user

    def sync_strava_activities
      connection = user.strava_connection
      return 0 unless connection

      raw_activities = Strava::Client.new(connection).list_activities(per_page: PER_PAGE)
      existing_ids = user.strava_activities.pluck(:strava_id).to_set
      new_activities = raw_activities.reject { |a| existing_ids.include?(a["id"]) }

      new_activities.each do |raw|
        user.strava_activities.create!(strava_id: raw["id"], raw_data: raw, occurred_at: raw["start_date"])
      end

      new_activities.size
    end

    def review_description(new_activity_count, program)
      reasons = []
      reasons << "#{new_activity_count} new Strava #{"activity".pluralize(new_activity_count)} synced just now" if new_activity_count.positive?
      reasons << "unreviewed Strava activity from before this sync" if new_activity_count.zero? && user.strava_activities.where("created_at > ?", program.updated_at).exists?
      reasons << "new nutrition logs since the last review" if user.nutrition_logs.where("created_at > ?", program.updated_at).exists?
      reasons << "the schedule running low on upcoming days" if program.needs_extending?
      reasons << "a routine check-in" if reasons.empty?

      "Checked for updates: #{reasons.join(", ")}."
    end
  end
end
