class StravaConnection < ApplicationRecord
  belongs_to :user

  encrypts :access_token
  encrypts :refresh_token

  validates :strava_athlete_id, presence: true, uniqueness: true

  def expired?
    expires_at.nil? || expires_at <= Time.current
  end
end
