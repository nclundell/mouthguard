require "net/http"
include ApplicationHelper

class LiveGameUpdateJob < ApplicationJob
  queue_as :live_update

  def perform(*args)
    puts "Updating live games..."

    Game.live.each do |game|
      game_data = JSON.parse(make_request(game).body)

      game["status"]    = game_data["status"]
      game["clock"]     = game_data["drives"].last["plays"].last["clock"]
      game["last_play"] = game_data["drives"].last["plays"].last["playText"]
      game["period"]    = game_data["drives"].last["plays"].last["period"]
      game["completed"] = game["status"] == "completed" ? true : false

      game_data["teams"].each do |team|
        if team["homeAway"] == "home"
          game["home_points"]      = team["points"]
          game["home_line_scores"] = team["lineScores"]
        else
          game["away_points"]      = team["points"]
          game["away_line_scores"] = team["lineScores"]
        end
      end

      game.save!
    end
  end

  private

  def make_request(game)
    uri = URI("https://api.collegefootballdata.com/live/plays?gameId=#{game.cfbd_id}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Authorization"] = "Bearer #{Rails.application.credentials.cfbd_key}"
    request["Content-Type"] = "application/json"

    http.start do |http|
      http.request(request)
    end
  end
end
