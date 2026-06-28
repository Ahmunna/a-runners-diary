module Strava
  # Pulls the athlete's most recent Strava activities and stores anything
  # not already synced via webhook. Used both right after connecting Strava
  # (one-time backfill) and from the dashboard's manual "Sync now" button
  # (catch-up if a webhook event was ever missed).
  #
  # Deliberately triggers at most one Coach review for the whole batch,
  # not one per activity — a backfill can pull in many activities at once,
  # and reacting to each individually would multiply Claude cost and could
  # fire a flurry of push notifications for old history.
  class SyncActivities
    PER_PAGE = 30

    def self.call(user) = new(user).call

    def initialize(user)
      @user = user
    end

    def call
      connection = user.strava_connection
      return 0 unless connection

      raw_activities = Strava::Client.new(connection).list_activities(per_page: PER_PAGE)
      existing_ids = user.strava_activities.pluck(:strava_id).to_set
      new_activities = raw_activities.reject { |a| existing_ids.include?(a["id"]) }

      new_activities.each do |raw|
        user.strava_activities.create!(strava_id: raw["id"], raw_data: raw, occurred_at: raw["start_date"])
      end

      if new_activities.any?
        Coach::ReactToActivityJob.perform_later(user.id, "Synced #{new_activities.size} Strava #{"activity".pluralize(new_activities.size)} from history — review training load.")
      end

      new_activities.size
    end

    private

    attr_reader :user
  end
end
