class TrainingDay < ApplicationRecord
  belongs_to :training_program

  STATUSES = %w[pending completed skipped].freeze

  validates :date, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :past_due, -> { where(status: "pending").where("date < ?", Date.current) }
end
