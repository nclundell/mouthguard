require "net/http"
include ApplicationHelper

class LoadGameMediaJob < ApplicationJob
  queue_as :data_loading

  def perform(*args)
    puts "Loading Media Info for #{current_season} games..."

    return if Game.this_season.with_no_media.blank?

    media_listings = JSON.parse(make_request.body)
    media_listings.each do |listing|
      game = Game.find_by(cfbd_id: listing["id"])
      game.update(tv: listing["outlet"]) unless game.blank?
    end
  end

  private

  def uri
    @uri ||= URI("https://apinext.collegefootballdata.com/games/media?year=#{current_season}&seasonType=postseason&mediaType=tv&classification=fbs")
  end

  def make_request
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
