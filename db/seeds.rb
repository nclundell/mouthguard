# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Calling Rake Tasks: Order Matters Here!
nathan = User.find_or_initialize_by(
  email_address: Rails.application.credentials.nclundell_email_address
)
nathan.password = Rails.application.credentials.nclundell_password
nathan.first_name = "Nathan"
nathan.last_name = "Lundell"
nathan.save!

LoadVenuesJob.perform_now
LoadTeamsJob.perform_now
LoadGamesJob.perform_now
LoadLegendsJob.perform_now
