class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  ROLES = %w[athlete admin].freeze

  has_one :athlete_profile, dependent: :destroy
  has_one :claude_credential, dependent: :destroy
  has_one :strava_connection, dependent: :destroy
  has_one :race, dependent: :destroy
  has_many :nutrition_logs, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :strava_activities, dependent: :destroy

  validates :first_name, :last_name, presence: true
  validates :role, inclusion: { in: ROLES }

  def admin? = role == "admin"

  def full_name = "#{first_name} #{last_name}"

  def onboarded?
    athlete_profile.present? && race.present?
  end
end
