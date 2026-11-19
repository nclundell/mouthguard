require "test_helper"
require_relative "../db/seeders/venues"
require "ostruct"

class VenuesSeederTest < ActiveSupport::TestCase
  test "maps CFBD venues and updates existing records when run again" do
    source = OpenStruct.new(
      id: 42,
      name: "Example Stadium",
      city: "Example City",
      state: "TX",
      zip: "12345",
      countryCode: "US",
      timezone: "America/Chicago",
      capacity: 50000,
      constructionYear: 1980,
      grass: true,
      dome: false
    )
    with_rest_venues([ source ]) do
      assert_difference("Venue.count", 1) { VenuesSeeder.seed! }

      saved = Venue.find_by!(cfbd_id: 42)
      assert_equal "Example Stadium", saved.name
      assert_equal "Example City", saved.city
      assert_equal "TX", saved.state
      assert_equal "12345", saved.zip
      assert_equal "US", saved.country_code
      assert_equal "America/Chicago", saved.timezone
      assert_equal 50000, saved.capacity
      assert_equal 1980, saved.construction_year
      assert_equal true, saved.grass
      assert_equal false, saved.dome

      source.name = "Renamed Stadium"
      source.constructionYear = 1981
      assert_no_difference("Venue.count") { VenuesSeeder.seed! }
      assert_equal saved.id, Venue.find_by!(cfbd_id: 42).id
      assert_equal "Renamed Stadium", saved.reload.name
      assert_equal 1981, saved.construction_year
    end
  end

  test "rolls back earlier inserts and updates when a later venue lacks a CFBD ID" do
    existing = Venue.create!(cfbd_id: 41, name: "Original Stadium")
    sources = [
      OpenStruct.new(id: 41, name: "Renamed Stadium"),
      OpenStruct.new(id: 42, name: "New Stadium"),
      OpenStruct.new(name: "Unknown Stadium")
    ]
    with_rest_venues(sources) do
      assert_no_difference("Venue.count") do
        error = assert_raises(ActiveRecord::NotNullViolation) { VenuesSeeder.seed! }
        assert_match(/cfbd_id/, error.message)
      end
    end

    assert_nil Venue.find_by(cfbd_id: 42)
    assert_equal "Original Stadium", existing.reload.name
  end

  private

  def with_rest_venues(venues)
    original = Cfbd::Rest.method(:venues)
    Cfbd::Rest.define_singleton_method(:venues) { venues }
    yield
  ensure
    Cfbd::Rest.define_singleton_method(:venues, original)
  end
end
