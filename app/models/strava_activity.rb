class StravaActivity < ApplicationRecord
  belongs_to :user

  validates :strava_id, presence: true, uniqueness: true

  def distance_km
    return nil unless raw_data

    (raw_data["distance"].to_f / 1000).round(2)
  end

  def duration_minutes
    return nil unless raw_data

    (raw_data["moving_time"].to_f / 60).round
  end

  def pace_per_km
    return nil if distance_km.blank? || distance_km.zero?

    (duration_minutes / distance_km).round(2)
  end
end
