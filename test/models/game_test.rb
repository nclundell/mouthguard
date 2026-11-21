require "test_helper"
require "turbo/broadcastable/test_helper"

class GameTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  test "broadcasts a replacement card after an updated game commits" do
    game = Game.create!(cfbd_id: 100, season: Current.season, notes: "Before")

    streams = capture_turbo_stream_broadcasts("games") { game.update!(notes: "After", home_points: 14) }

    assert_equal 1, streams.size
    assert_equal "replace", streams.first["action"]
    assert_equal "game_#{game.id}", streams.first["target"]
    assert_equal "After", streams.first.at_css("template a#game_#{game.id} h2").text
    assert_equal "14", streams.first.at_css("template a#game_#{game.id} span.text-lg").text
  end

  test "does not broadcast unchanged or rolled-back updates" do
    game = Game.create!(cfbd_id: 101, notes: "Before")

    assert_turbo_stream_broadcasts "games", count: 0 do
      game.update!(notes: "Before")
      Game.transaction do
        game.update!(notes: "Discarded")
        raise ActiveRecord::Rollback
      end
    end
    assert_equal "Before", game.reload.notes
  end

  test "live includes started incomplete games only" do
    travel_to Time.zone.local(2026, 11, 21, 12) do
      started = Game.create!(cfbd_id: 1, start: 1.hour.ago, completed: false, status: "in_progress")
      starting_now = Game.create!(cfbd_id: 2, start: Time.current, completed: nil, status: "in_progress")
      Game.create!(cfbd_id: 3, start: 1.hour.from_now, completed: false)
      Game.create!(cfbd_id: 4, start: 1.hour.ago, completed: true)
      Game.create!(cfbd_id: 5, completed: false)
      Game.create!(cfbd_id: 6, start: 1.hour.ago, completed: false, status: "completed")

      assert_equal [ started.id, starting_now.id ], Game.live.order(:id).pluck(:id)
    end
  end
end
