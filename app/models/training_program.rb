class TrainingProgram < ApplicationRecord
  belongs_to :race
  has_many :training_days, dependent: :destroy

  STATUSES = %w[active superseded].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }

  def today
    training_days.find_by(date: Date.current)
  end
end
