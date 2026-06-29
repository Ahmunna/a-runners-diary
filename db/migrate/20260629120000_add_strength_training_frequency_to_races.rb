class AddStrengthTrainingFrequencyToRaces < ActiveRecord::Migration[7.2]
  def change
    add_column :races, :strength_training_frequency, :string, default: "none", null: false
  end
end
