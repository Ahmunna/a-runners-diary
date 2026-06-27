class Message < ApplicationRecord
  belongs_to :user

  ROLES = %w[user assistant].freeze

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true
end
