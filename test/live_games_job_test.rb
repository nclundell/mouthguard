require "test_helper"
require "ostruct"

class LiveGamesJobTest < ActiveSupport::TestCase
  test "does not request the scoreboard when no games are live" do
    Game.create!(cfbd_id: 101, start: 1.hour.from_now)
    with_scoreboard([ OpenStruct.new(id: 101) ]) do |requests|
      LiveGamesJob.perform_now
      assert_equal 0, requests.size
    end
  end

  test "refreshes only matching live games" do
    game = Game.create!(
      cfbd_id: 201, start: 1.hour.ago, completed: false,
      home_points: 7, situation: "Old situation", tv: "ESPN"
    )
    scheduled = Game.create!(cfbd_id: 202, start: 1.hour.from_now)
    source = OpenStruct.new(
      id: 201, startDate: 1.day.from_now.iso8601, status: "in_progress",
      period: 3, clock: "10:30", tv: "FOX", situation: nil,
      possession: "Home", lastPlay: "Touchdown",
      homeTeam: OpenStruct.new(id: 999, points: 14, lineScores: [ 7, 0, 7 ]),
      awayTeam: OpenStruct.new(id: 998, points: 10, lineScores: [ 3, 7, 0 ]),
      venue: OpenStruct.new(name: "Other Stadium")
    )
    with_scoreboard([ source, OpenStruct.new(id: 202, status: "completed"), OpenStruct.new(id: 203) ]) do |requests|
      assert_no_difference("Game.count") { LiveGamesJob.perform_now }
      assert_equal 1, requests.size
    end

    game.reload
    assert_equal 14, game.home_points
    assert_equal 10, game.away_points
    assert_equal [ 7, 0, 7 ], game.home_line_scores
    assert_equal [ 3, 7, 0 ], game.away_line_scores
    assert_equal "in_progress", game.status
    assert_equal "3", game.period
    assert_equal "10:30", game.clock
    assert_equal "FOX", game.tv
    assert_nil game.situation
    assert_equal "Home", game.possession
    assert_equal "Touchdown", game.last_play
    assert_in_delta 1.hour.ago.to_f, game.start.to_f, 2
    assert_nil game.home
    assert_nil game.away
    assert_nil game.venue
    assert_nil scheduled.reload.status
    assert_nil Game.find_by(cfbd_id: 203)
  end

  test "marks completed games so they stop triggering requests" do
    game = Game.create!(cfbd_id: 301, start: 1.hour.ago, completed: false, tv: "ESPN", clock: "05:00")
    source = OpenStruct.new(id: 301, status: "completed", homeTeam: OpenStruct.new(points: 28))

    with_scoreboard([ source ]) do |requests|
      LiveGamesJob.perform_now
      assert_equal true, game.reload.completed
      assert_equal "completed", game.status
      assert_equal 28, game.home_points
      assert_equal "ESPN", game.tv
      assert_equal "05:00", game.clock
      LiveGamesJob.perform_now
      assert_equal 1, requests.size
    end
  end

  private

  def with_scoreboard(games)
    original = Cfbd::Rest.method(:scoreboard)
    requests = []
    Cfbd::Rest.define_singleton_method(:scoreboard) { requests << true; games }
    yield requests
  ensure
    Cfbd::Rest.define_singleton_method(:scoreboard, original)
  end
end
