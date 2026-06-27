class CreateStravaActivities < ActiveRecord::Migration[7.2]
  def change
    create_table :strava_activities do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint :strava_id
      t.jsonb :raw_data
      t.text :claude_analysis
      t.datetime :occurred_at

      t.timestamps
    end
    add_index :strava_activities, :strava_id, unique: true
  end
end
