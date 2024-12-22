require 'net/http'

namespace :venues do
  desc "Get Venue from CFBD"

  task load: [ :environment] do
    puts "Loading venues..."

    uri = URI("https://apinext.collegefootballdata.com/venues")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Authorization"] = "Bearer #{Rails.application.credentials.cfbd_key}"
    request["Content-Type"] = "application/json"

    response = http.start do |http|
      http.request(request)
    end

    venues = JSON.parse(response.body)

    venues.each do |venue_data|
      venue = Venue.find_or_initialize_by(cfbd_id: venue_data["id"])
      venue["name"]              = venue_data["name"]
      venue["city"]              = venue_data["city"]
      venue["state"]             = venue_data["state"]
      venue["zip"]               = venue_data["zip"]
      venue["country_code"]      = venue_data["countryCode"]
      venue["timezone"]          = venue_data["timezone"]
      venue["capacity"]          = venue_data["capacity"]
      venue["construction_year"] = venue_data["constructionYear"]
      venue["grass"]             = venue_data["grass"]
      venue["dome"]              = venue_data["dome"]
      venue.save!
    end
  end
end
