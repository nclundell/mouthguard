require "net/http"
require "json"

module Cfbd
  class Rest
    CFBD_API_KEY = Rails.application.credentials.cfbd.api_key
    def info
      get("info")
    end

    private

    def get(path)
      uri = URI("https://api.collegefootballdata.com/#{path}")
      request = Net::HTTP::Get.new(uri.request_uri)
      request["Authorization"] = "Bearer #{CFBD_API_KEY}"

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      raise "CFBD request failed (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end
end
