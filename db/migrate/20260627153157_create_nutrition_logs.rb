class CreateNutritionLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :nutrition_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date
      t.integer :calories
      t.integer :protein_g
      t.integer :carbs_g
      t.integer :fat_g
      t.text :notes

      t.timestamps
    end
    add_index :nutrition_logs, [ :user_id, :date ], unique: true
  end
end
