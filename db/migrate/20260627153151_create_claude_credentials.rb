class CreateClaudeCredentials < ActiveRecord::Migration[7.2]
  def change
    create_table :claude_credentials do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.text :api_key

      t.timestamps
    end
  end
end
