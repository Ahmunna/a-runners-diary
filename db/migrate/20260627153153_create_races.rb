class CreateRaces < ActiveRecord::Migration[7.2]
  def change
    create_table :races do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :race_type
      t.date :race_date
      t.string :time_objective
      t.string :difficulty

      t.timestamps
    end
  end
end
