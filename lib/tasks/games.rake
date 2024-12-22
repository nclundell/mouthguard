require 'net/http'

namespace :games do
  desc "Get game from CFBD"

  task load: [:environment] do
    puts "Loading games..."

    season = Rails.application.credentials.season

    uri = URI("https://apinext.collegefootballdata.com/games?year=#{season}&classification=fbs&seasonType=postseason")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Authorization"] = "Bearer #{Rails.application.credentials.cfbd_key}"
    request["Content-Type"] = "application/json"

    response = http.start do |http|
      http.request(request)
    end

    games = JSON.parse(response.body)

    games.each do |game_data|;
      game = Game.find_or_initialize_by(cfbd_id: game_data["id"])
      game["season"]           = game_data["season"]
      game["start"]            = game_data["startDate"]
      game["completed"]        = game_data["completed"]
      game["attendance"]       = game_data["attendance"]
      game["venue_id"]         = Venue.find_by(cfbd_id: game_data["venueId"])&.id
      game["home_id"]          = Team.find_by(cfbd_id: game_data["homeId"])&.id
      game["home_points"]      = game_data["homePoints"]
      game["home_line_scores"] = game_data["homeLineScores"]
      game["away_id"]          = Team.find_by(cfbd_id: game_data["awayId"])&.id
      game["away_points"]      = game_data["awayPoints"]
      game["away_line_scores"] = game_data["awayLineScores"]
      game["highlights"]       = game_data["highlights"]
      game["notes"]            = game_data["notes"]
      game.save!
    end
  end

  task live_update: [:environment] do
    puts "Updating live games..."

    season = Rails.application.credentials.season

    uri = URI("https://apinext.collegefootballdata.com/scoreboard?classification=fbs")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Authorization"] = "Bearer #{Rails.application.credentials.cfbd_key}"
    request["Content-Type"] = "application/json"

    response = http.start do |http|
      http.request(request)
    end

    games = JSON.parse(response.body)

    games.each do |game_data|
      game = Game.find_or_initialize_by(cfbd_id: game_data["id"])
      unless game["status"] == "completed"
        game["tv"]               = game_data["tv"]
        game["status"]           = game_data["status"]
        game["period"]           = game_data["period"]
        game["clock"]            = game_data["clock"]
        game["situation"]        = game_data["situation"]
        game["possession"]       = game_data["possession"]
        game["last_play"]        = game_data["lastPlay"]
        game["home_points"]      = game_data["homeTeam"]["points"]
        game["home_line_scores"] = game_data["homeTeam"]["lineScores"]
        game["away_points"]      = game_data["awayTeam"]["points"]
        game["away_line_scores"] = game_data["awayTeam"]["lineScores"]
      else
        game["period"]           = nil
        game["clock"]            = nil
        game["situation"]        = nil
        game["possession"]       = nil
        game["last_play"]        = nil
        game["home_points"]      = game_data["homeTeam"]["points"]
        game["home_line_scores"] = game_data["homeTeam"]["lineScores"]
        game["away_points"]      = game_data["awayTeam"]["points"]
        game["away_line_scores"] = game_data["awayTeam"]["lineScores"]
      end
      game.save!
    end
  end
end
