class TrainingWeek < ApplicationRecord
  belongs_to :training_program

  PHASES = %w[base build peak taper race_week].freeze

  validates :week_number, presence: true, uniqueness: { scope: :training_program_id }
  validates :start_date, :end_date, presence: true
  validates :phase, inclusion: { in: PHASES }

  scope :ordered, -> { order(:week_number) }

  def phase_label
    phase == "race_week" ? "Race week" : phase.humanize
  end

  def current?
    Date.current.between?(start_date, end_date)
  end

  def badge_class
    { "base" => "badge-info", "build" => "badge-warning", "peak" => "badge-peak",
      "taper" => "badge-success", "race_week" => "badge-race-week" }.fetch(phase, "badge-neutral")
  end
end
