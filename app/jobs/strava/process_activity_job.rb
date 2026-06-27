module Strava
  class ProcessActivityJob < ApplicationJob
    queue_as :default

    def perform(strava_athlete_id, strava_activity_id)
      connection = StravaConnection.find_by(strava_athlete_id: strava_athlete_id)
      return unless connection

      user = connection.user
      raw = Strava::Client.new(connection).fetch_activity(strava_activity_id)

      activity = user.strava_activities.find_or_initialize_by(strava_id: strava_activity_id)
      activity.update!(raw_data: raw, occurred_at: raw["start_date"])

      Coach::ReactToActivityJob.perform_later(
        user.id,
        "New Strava activity synced: #{activity.distance_km}km in #{activity.duration_minutes}min, pace #{activity.pace_per_km} min/km."
      )
    end
  end
end
