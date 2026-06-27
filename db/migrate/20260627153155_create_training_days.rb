class CreateTrainingDays < ActiveRecord::Migration[7.2]
  def change
    create_table :training_days do |t|
      t.references :training_program, null: false, foreign_key: true
      t.date :date
      t.text :workout
      t.string :status

      t.timestamps
    end
    add_index :training_days, [ :training_program_id, :date ], unique: true
  end
end
