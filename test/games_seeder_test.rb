require "test_helper"
require_relative "../db/seeders/games"
require "ostruct"

class GamesSeederTest < ActiveSupport::TestCase
  test "maps postseason games to local teams and venues and updates them on reseed" do
    home = Team.create!(cfbd_id: 501, school: "Home")
    away = Team.create!(cfbd_id: 502, school: "Away")
    venue = Venue.create!(cfbd_id: 503, name: "Stadium")
    source = OpenStruct.new(
      id: 504, season: 2026, startDate: "2026-12-28T20:00:00Z",
      completed: false, attendance: 70000, venueId: 503, homeId: 501, awayId: 502,
      homePoints: 0, awayPoints: 17, homeLineScores: [ 0, 0 ], awayLineScores: [ 7, 10 ],
      highlights: "https://example.com/highlights", notes: "College Football Playoff - Presented by Example",
      tv: "ESPN", status: "In Progress", period: "2", clock: "10:00",
      situation: "1st & 10", possession: "Home", lastPlay: "Run"
    )
    with_rest_games([ source ]) do |params|
      assert_difference("Game.count", 1) { GamesSeeder.seed! }
      assert_equal({ year: Current.season, seasonType: "postseason", classification: "fbs" }, params.first)
      game = Game.find_by!(cfbd_id: 504)
      assert_equal 2026, game.season
      assert_equal Time.iso8601("2026-12-28T20:00:00Z"), game.start
      assert_equal false, game.completed
      assert_equal 70000, game.attendance
      assert_equal venue, game.venue
      assert_equal home, game.home
      assert_equal away, game.away
      assert_equal 0, game.home_points
      assert_equal 17, game.away_points
      assert_equal [ 0, 0 ], game.home_line_scores
      assert_equal [ 7, 10 ], game.away_line_scores
      assert_equal "https://example.com/highlights", game.highlights
      assert_equal "CFP", game.notes
      assert_equal true, game.playoff
      assert_nil game.tv
      assert_nil game.status
      assert_nil game.period
      assert_nil game.clock
      assert_nil game.situation
      assert_nil game.possession
      assert_nil game.last_play
      game.update!(
        tv: "FOX", status: "Final", period: "4", clock: "00:00",
        situation: "Game over", possession: "Away", last_play: "Kneel"
      )

      source.homePoints = 21
      source.venueId = nil
      source.notes = nil
      source.tv = nil
      source.status = nil
      source.period = nil
      source.clock = nil
      source.situation = nil
      source.possession = nil
      source.lastPlay = nil
      assert_no_difference("Game.count") { GamesSeeder.seed! }
      assert_equal game.id, Game.find_by!(cfbd_id: 504).id
      assert_equal 21, game.reload.home_points
      assert_nil game.venue
      assert_equal "", game.notes
      assert_equal false, game.playoff
      assert_equal "FOX", game.tv
      assert_equal "Final", game.status
      assert_equal "4", game.period
      assert_equal "00:00", game.clock
      assert_equal "Game over", game.situation
      assert_equal "Away", game.possession
      assert_equal "Kneel", game.last_play
    end
  end

  test "allows blank team IDs for undecided matchups" do
    source = OpenStruct.new(id: 605, homeId: " ", awayId: nil, notes: "TBD")
    with_rest_games([ source ]) { GamesSeeder.seed! }

    game = Game.find_by!(cfbd_id: 605)
    assert_nil game.home
    assert_nil game.away
  end

  test "rolls back inserts and updates when a supplied team ID is unresolved" do
    existing = Game.create!(cfbd_id: 606, notes: "Original")
    sources = [
      OpenStruct.new(id: 606, notes: "Updated"),
      OpenStruct.new(id: 607, notes: "New"),
      OpenStruct.new(id: 608, homeId: 9999, notes: "Missing home")
    ]

    with_rest_games(sources) do
      assert_no_difference("Game.count") do
        error = assert_raises(ActiveRecord::RecordNotFound) { GamesSeeder.seed! }
        assert_match(/home Team.*9999/, error.message)
      end
    end
    assert_equal "Original", existing.reload.notes
    assert_nil Game.find_by(cfbd_id: 607)

    sources.last.homeId = nil
    sources.last.awayId = 9998
    with_rest_games(sources) do
      assert_no_difference("Game.count") do
        error = assert_raises(ActiveRecord::RecordNotFound) { GamesSeeder.seed! }
        assert_match(/away Team.*9998/, error.message)
      end
    end
    assert_equal "Original", existing.reload.notes
    assert_nil Game.find_by(cfbd_id: 607)
  end

  test "rolls back updates and inserts when a game lacks a CFBD ID" do
    existing = Game.create!(cfbd_id: 601, notes: "Original")
    sources = [
      OpenStruct.new(id: 601, notes: "Updated"),
      OpenStruct.new(id: 602, notes: "New"),
      OpenStruct.new(notes: "Missing ID")
    ]
    with_rest_games(sources) do
      assert_no_difference("Game.count") do
        assert_raises(ActiveRecord::NotNullViolation) { GamesSeeder.seed! }
      end
    end
    assert_equal "Original", existing.reload.notes
    assert_nil Game.find_by(cfbd_id: 602)
  end

  private

  def with_rest_games(games)
    original = Cfbd::Rest.method(:games)
    params = []
    Cfbd::Rest.define_singleton_method(:games) { |**filters| params << filters; games }
    yield params
  ensure
    Cfbd::Rest.define_singleton_method(:games, original)
  end
end
