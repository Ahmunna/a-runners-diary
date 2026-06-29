class Race < ApplicationRecord
  belongs_to :user
  has_many :training_programs, dependent: :destroy

  TYPES = %w[5k 10k half_marathon marathon hyrox].freeze
  DIFFICULTIES = %w[beginner intermediate advanced].freeze
  STRENGTH_TRAINING_LABELS = {
    "none" => "None — running only",
    "1_2_per_week" => "1-2x/week",
    "3_4_per_week" => "3-4x/week",
    "5_plus_per_week" => "5+x/week"
  }.freeze
  STRENGTH_TRAINING_FREQUENCIES = STRENGTH_TRAINING_LABELS.keys.freeze

  validates :race_type, inclusion: { in: TYPES }
  validates :race_date, presence: true
  validates :difficulty, inclusion: { in: DIFFICULTIES }
  validates :strength_training_frequency, inclusion: { in: STRENGTH_TRAINING_FREQUENCIES }
  validate :race_date_in_future

  def active_program
    training_programs.find_by(status: "active")
  end

  def distance_label
    { "5k" => "5K", "10k" => "10K", "half_marathon" => "Half Marathon", "marathon" => "Marathon", "hyrox" => "Hyrox" }.fetch(race_type, race_type)
  end

  def hyrox?
    race_type == "hyrox"
  end

  def wants_strength_training?
    strength_training_frequency != "none"
  end

  def strength_training_label
    STRENGTH_TRAINING_LABELS.fetch(strength_training_frequency, strength_training_frequency)
  end

  private

  def race_date_in_future
    errors.add(:race_date, "must be in the future") if race_date.present? && race_date <= Date.current
  end
end
