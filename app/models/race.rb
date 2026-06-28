class Race < ApplicationRecord
  belongs_to :user
  has_many :training_programs, dependent: :destroy

  TYPES = %w[5k 10k half_marathon marathon hyrox].freeze
  DIFFICULTIES = %w[beginner intermediate advanced].freeze

  validates :race_type, inclusion: { in: TYPES }
  validates :race_date, presence: true
  validates :difficulty, inclusion: { in: DIFFICULTIES }
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

  private

  def race_date_in_future
    errors.add(:race_date, "must be in the future") if race_date.present? && race_date <= Date.current
  end
end
