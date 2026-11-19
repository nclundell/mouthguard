require "net/http"
require "json"
require "ostruct"

module Cfbd
  class Rest
    CFBD_API_KEY = Rails.application.credentials.cfbd.api_key
    class << self
      def info
        get("info")
      end

      def teams
        get("teams")
      end

      def venues
        get("venues")
      end

      def games(**params)
        get("games", params)
      end

      private

      def get(path, params = {})
        uri = URI("https://api.collegefootballdata.com/#{path}")
        query = params.reject { |_, value| value.blank? }
        uri.query = URI.encode_www_form(query) if query.any?
        request = Net::HTTP::Get.new(uri.request_uri)
        request["Authorization"] = "Bearer #{CFBD_API_KEY}"

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        raise "CFBD request failed (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body, object_class: OpenStruct)
      end
    end
  end
end
