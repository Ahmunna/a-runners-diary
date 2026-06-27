class CreateStravaConnections < ActiveRecord::Migration[7.2]
  def change
    create_table :strava_connections do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.bigint :strava_athlete_id
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at

      t.timestamps
    end
  end
end
