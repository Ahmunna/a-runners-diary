class AddCoachingPreferencesToAthleteProfiles < ActiveRecord::Migration[7.2]
  def change
    add_column :athlete_profiles, :timezone, :string
    add_column :athlete_profiles, :last_daily_checkin_on, :date
    add_column :athlete_profiles, :review_on_chat, :boolean, default: false, null: false
    add_column :athlete_profiles, :review_on_nutrition_log, :boolean, default: false, null: false
  end
end
