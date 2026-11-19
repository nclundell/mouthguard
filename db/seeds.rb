# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
require_relative "seeders/teams"
require_relative "seeders/venues"
require_relative "seeders/games"
require_relative "seeders/legends"

dev = Rails.application.credentials.dev
User.find_or_create_by!(email_address: dev.email_address) do |user|
  user.first_name = dev.first_name
  user.last_name = dev.last_name
  user.display_name = dev.first_name
  user.password = dev.password
end

TeamsSeeder.seed!
VenuesSeeder.seed!
GamesSeeder.seed!
LegendsSeeder.seed!
