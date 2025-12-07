require "net/http"
include ApplicationHelper

class LiveGameUpdateJob < ApplicationJob
  queue_as :live_update

  def perform(*args)
    puts "Updating #{current_season} live games..."

    unless Game.this_season.live.count > 0
      puts "No live #{current_season} games found, skipping update."
      return
    end


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
      game = Game.find_by(cfbd_id: game_data["id"])
      return unless game.present?

      if game.is_live?
        game["period"]     = game_data["period"]
        game["clock"]      = game_data["clock"]
        game["situation"]  = game_data["situation"]
        game["possession"] = game_data["possession"]
        game["last_play"]  = game_data["lastPlay"]
      else
        game["period"]     = nil
        game["clock"]      = nil
        game["situation"]  = nil
        game["possession"] = nil
        game["last_play"]  = nil
      end
      game["tv"]               = game_data["tv"]
      game["completed"]        = game_data["status"] == "completed" ? true : false
      game["home_points"]      = game_data["homeTeam"]["points"]
      game["home_line_scores"] = game_data["homeTeam"]["lineScores"]
      game["away_points"]      = game_data["awayTeam"]["points"]
      game["away_line_scores"] = game_data["awayTeam"]["lineScores"]
      game.save!
    end
  end
end
