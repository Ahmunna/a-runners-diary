class TrainingProgram < ApplicationRecord
  belongs_to :race
  has_many :training_days, dependent: :destroy
  has_many :training_weeks, dependent: :destroy

  STATUSES = %w[active superseded].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }

  def today
    training_days.find_by(date: Date.current)
  end

  def current_week
    training_weeks.find_by("start_date <= ? AND end_date >= ?", Date.current, Date.current)
  end

  # Whether anything has happened since claude_summary was last written
  # that's actually worth asking Claude to react to. Used to gate every
  # trigger that isn't itself inherently new information (the daily
  # check-in, the manual "check for updates" button) — without this,
  # those fire on schedule/on click regardless of whether there's
  # anything new, and Claude ends up writing a low-value "you gave me
  # nothing to work with" message that overwrites a perfectly good
  # existing summary.
  def new_data_since_last_review?
    user = race.user
    user.strava_activities.where("created_at > ?", updated_at).exists? ||
      user.nutrition_logs.where("created_at > ?", updated_at).exists?
  end

  # Independent of whether anything new happened — the schedule itself
  # might just be running low and need topping up, or the weekly roadmap
  # might not reach race day yet (capped at GenerateProgram::MAX_ROADMAP_WEEKS
  # on initial generation for very long lead times).
  def needs_extending?
    training_days.where(status: "pending").where("date >= ?", Date.current).count < Coach::ReactToActivity::MIN_PENDING_DAYS_BUFFER ||
      roadmap_incomplete?
  end

  def roadmap_incomplete?
    last_week_end = training_weeks.maximum(:end_date)
    last_week_end.nil? || last_week_end < race.race_date
  end

  def review_worthwhile?
    new_data_since_last_review? || needs_extending?
  end
end
