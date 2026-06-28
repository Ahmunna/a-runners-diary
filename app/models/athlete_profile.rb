class AthleteProfile < ApplicationRecord
  belongs_to :user

  SEXES = %w[male female].freeze

  validates :age, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :height_cm, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :sex, inclusion: { in: SEXES }, allow_nil: true
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }, allow_nil: true

  def time_zone
    ActiveSupport::TimeZone[timezone.presence || "UTC"]
  end

  def local_hour_now
    time_zone.now.hour
  end

  def checked_in_today?
    last_daily_checkin_on == time_zone.today
  end
end
