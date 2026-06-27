class AthleteProfile < ApplicationRecord
  belongs_to :user

  SEXES = %w[male female].freeze

  validates :age, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :height_cm, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :sex, inclusion: { in: SEXES }, allow_nil: true
end
