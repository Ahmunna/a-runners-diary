class CreateAthleteProfiles < ActiveRecord::Migration[7.2]
  def change
    create_table :athlete_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer :age
      t.string :sex
      t.integer :height_cm
      t.text :notes

      t.timestamps
    end
  end
end
