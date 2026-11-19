require "test_helper"

class CfbdRestTest < ActiveSupport::TestCase
  test "fetches account info with the configured key" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:body) { '{"name":"example","remainingCalls":100,"features":{"graphQl":true}}' }

    stub_const(Cfbd::Rest, :CFBD_API_KEY, "test-key") do
      with_http_response(response) do |requests|
        info = Cfbd::Rest.info
        assert_equal "example", info.name
        assert_equal 100, info.remainingCalls
        assert_equal true, info.features.graphQl
        assert_equal 1, requests.size
        assert_equal "/info", requests.first.path
        assert_equal "Bearer test-key", requests.first["Authorization"]
      end
    end
  end

  test "fetches teams with the configured key" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:body) { '[{"id":1,"school":"Example"}]' }

    stub_const(Cfbd::Rest, :CFBD_API_KEY, "test-key") do
      with_http_response(response) do |requests|
        teams = Cfbd::Rest.teams
        assert_equal 1, teams.size
        assert_equal 1, teams.first.id
        assert_equal "Example", teams.first.school
        assert_equal 1, requests.size
        assert_equal "/teams", requests.first.path
        assert_equal "Bearer test-key", requests.first["Authorization"]
      end
    end
  end

  test "fetches venues with the configured key" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:body) { '[{"id":7,"name":"Example Stadium"}]' }

    stub_const(Cfbd::Rest, :CFBD_API_KEY, "test-key") do
      with_http_response(response) do |requests|
        venues = Cfbd::Rest.venues
        assert_equal 7, venues.first.id
        assert_equal "Example Stadium", venues.first.name
        assert_equal "/venues", requests.first.path
        assert_equal "Bearer test-key", requests.first["Authorization"]
      end
    end
  end

  test "fetches games with encoded filters, omitting blank values and without a body" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:body) { '[{"id":55}]' }

    with_http_response(response) do |requests|
      assert_equal 55, Cfbd::Rest.games(year: 2026, week: nil, seasonType: "post season", classification: "fbs", empty: "").first.id
      request = requests.first
      assert_equal "/games", URI(request.path).path
      assert_equal({ "year" => "2026", "seasonType" => "post season", "classification" => "fbs" },
        URI.decode_www_form(URI(request.path).query).to_h)
      assert_nil request.body
      Cfbd::Rest.games(id: 55, year: " ")
      assert_equal "/games", URI(requests.last.path).path
      assert_equal({ "id" => "55" }, URI.decode_www_form(URI(requests.last.path).query).to_h)
      Cfbd::Rest.games
      assert_equal "/games", requests.last.path
    end
  end

  test "reports unsuccessful responses without exposing the key" do
    response = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")

    stub_const(Cfbd::Rest, :CFBD_API_KEY, "private-key") do
      with_http_response(response) do
        error = assert_raises(RuntimeError) { Cfbd::Rest.info }
        assert_match(/401/, error.message)
        refute_includes error.message, "private-key"
      end
    end
  end

  private

  def with_http_response(response)
    requests = []
    test = self
    connection = Object.new
    connection.define_singleton_method(:request) { |request| requests << request; response }

    with_stub(Net::HTTP, :start, ->(host, port, options = {}, &block) {
      test.assert_equal "api.collegefootballdata.com", host
      test.assert_equal 443, port
      test.assert_equal true, options[:use_ssl]
      block.call(connection)
    }) { yield requests }
  end

  def with_stub(receiver, name, replacement)
    original = receiver.method(name)
    receiver.define_singleton_method(name, &replacement)
    yield
  ensure
    receiver.define_singleton_method(name, original) if original
  end
end
