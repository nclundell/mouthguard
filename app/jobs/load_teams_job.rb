require 'net/http'

class LoadTeamsJob < ApplicationJob
  queue_as :default

  def perform(*args)
    puts "Loading teams..."

    season = Rails.application.credentials.season
    uri = URI("https://apinext.collegefootballdata.com/teams/fbs?year=#{season}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Authorization"] = "Bearer #{Rails.application.credentials.cfbd_key}"
    request["Content-Type"] = "application/json"

    response = http.start do |http|
      http.request(request)
    end

    teams = JSON.parse(response.body)

    teams.each do |team_data|
      team = Team.find_or_initialize_by(cfbd_id: team_data["id"])
      team["school"]          = team_data["school"]
      team["mascot"]          = team_data["mascot"]
      team["abbreviation"]    = team_data["abbreviation"]
      team["alternate_names"] = team_data["alternateNames"]
      team["conference"]      = team_data["conference"]
      team["color"]           = team_data["color"]
      team["alternate_color"] = team_data["alternateColor"]
      team["logos"]           = team_data["logos"]
      team.save!
    end
  end
end
