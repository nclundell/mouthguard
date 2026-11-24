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

  test "broadcasts the updated hero to the game's stream" do
    game = Game.create!(cfbd_id: 102, notes: "Before", start: 1.hour.ago)

    streams = capture_turbo_stream_broadcasts(game) do
      game.update!(notes: "After", away_points: 7, home_points: 14, status: "completed")
    end

    assert_equal 1, streams.size
    assert_equal "replace", streams.first["action"]
    assert_equal "game_hero_#{game.id}", streams.first["target"]
    hero = streams.first.at_css("template section#game_hero_#{game.id}")
    assert_equal "After", hero.at_css("#matchup-title").text
    assert_equal "7", hero.at_css("[data-matchup] tbody tr:first-child td:last-child").text
    assert_equal "14", hero.at_css("[data-matchup] tbody tr:last-child td:last-child").text
    assert_equal "Final", hero.at_css("[data-game-status]").text
    assert_nil streams.first.at_css("template [data-picks-side]")
  end

  test "broadcasts dashboard scoreboard replacement independently of games cards" do
    game = Game.create!(cfbd_id: 104, season: Current.season, notes: "Before", start: 1.hour.ago)

    streams = capture_turbo_stream_broadcasts("dashboard_games") do
      game.update!(notes: "After", away_points: 7, home_points: 14, completed: true)
    end

    assert_equal 1, streams.size
    assert_equal "replace", streams.first["action"]
    assert_equal "game_#{game.id}", streams.first["target"]
    card = streams.first.at_css("template a#game_#{game.id}")
    assert_equal "After", card.at_css("h3").text
    assert_equal "final", card["data-scoreboard-status"]
    assert_equal game.start.iso8601, card["data-scoreboard-kickoff"]
    assert_equal [ "7", "14" ], card.css("tbody td:last-child").map(&:text)
    assert_nil card.at_css("[data-games-filter-target]")
  end

  test "does not broadcast unchanged or rolled-back updates" do
    game = Game.create!(cfbd_id: 101, notes: "Before")

    hero_streams = capture_turbo_stream_broadcasts(game) do
      assert_turbo_stream_broadcasts "games", count: 0 do
        assert_turbo_stream_broadcasts "dashboard_games", count: 0 do
          game.update!(notes: "Before")
          Game.transaction do
            game.update!(notes: "Discarded")
            raise ActiveRecord::Rollback
          end
        end
      end
    end
    assert_empty hero_streams
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

  test "winner is available only for completed games with known unequal scores" do
    away = Team.create!(cfbd_id: 250, school: "Away")
    home = Team.create!(cfbd_id: 251, school: "Home")
    game = Game.new(away: away, home: home, completed: true, away_points: 21, home_points: 14)

    assert_equal away, game.winner
    game.home_points = 28
    assert_equal home, game.winner
    game.completed = false
    assert_nil game.winner
    game.completed = nil
    assert_nil game.winner
    game.completed = true
    game.home_points = nil
    assert_nil game.winner
    game.home_points = 21
    assert_nil game.winner
    game.home_points = 28
    game.home = nil
    assert_nil game.winner
  end

  test "result changes settle, reverse and reset all existing picks" do
    away = Team.create!(cfbd_id: 260)
    home = Team.create!(cfbd_id: 261)
    game = Game.create!(cfbd_id: 262, away: away, home: home)
    away_pick = Pick.create!(game: game, user: users(:one), team: away)
    home_pick = Pick.create!(game: game, user: users(:two), team: home)

    assert_nil away_pick.reload.correct
    game.update!(completed: true, away_points: 21, home_points: 14)
    assert_equal true, away_pick.reload.correct
    assert_equal false, home_pick.reload.correct

    game.update!(home_points: 28)
    assert_equal false, away_pick.reload.correct
    assert_equal true, home_pick.reload.correct

    game.update!(away: nil)
    assert_equal false, away_pick.reload.correct
    assert_equal true, home_pick.reload.correct
    game.update!(home: nil)
    assert_nil away_pick.reload.correct
    assert_nil home_pick.reload.correct

    game.update!(home: home, away: away, home_points: 21)
    assert_nil away_pick.reload.correct
    game.update!(home_points: nil)
    assert_nil home_pick.reload.correct
    game.update!(home_points: 14)
    assert_equal true, away_pick.reload.correct
    game.update!(completed: false)
    assert_nil away_pick.reload.correct
    assert_nil home_pick.reload.correct
  end
end
