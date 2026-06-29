class CreateTrainingWeeks < ActiveRecord::Migration[7.2]
  def change
    create_table :training_weeks do |t|
      t.references :training_program, null: false, foreign_key: true
      t.integer :week_number, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :phase, null: false
      t.integer :target_distance_km
      t.text :focus

      t.timestamps
    end

    add_index :training_weeks, [ :training_program_id, :week_number ], unique: true
  end
end
