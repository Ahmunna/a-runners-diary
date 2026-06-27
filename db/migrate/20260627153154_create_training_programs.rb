class CreateTrainingPrograms < ActiveRecord::Migration[7.2]
  def change
    create_table :training_programs do |t|
      t.references :race, null: false, foreign_key: true
      t.string :status
      t.datetime :generated_at
      t.text :claude_summary

      t.timestamps
    end
  end
end
