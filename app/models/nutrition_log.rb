class NutritionLog < ApplicationRecord
  belongs_to :user

  validates :date, presence: true, uniqueness: { scope: :user_id }
  validates :calories, :protein_g, :carbs_g, :fat_g,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
