# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

if Rails.env.development?
  User.find_or_create_by!(email: "admin@runnersdiary.test") do |user|
    user.first_name = "Admin"
    user.last_name = "User"
    user.password = "password123"
    user.role = "admin"
  end
end
