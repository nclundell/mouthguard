require "test_helper"

class PickTest < ActiveSupport::TestCase
  test "persists an unpicked game and associates it with its user" do
    game = Game.create!(cfbd_id: 12345, season: Current.season)
    user = users(:one)

    pick = Pick.create!(game: game, user: user)

    assert_nil pick.reload.team
    assert_equal Current.season, pick.game.season
    assert_includes game.picks, pick
    assert_includes user.picks, pick
  end

  test "deleting a game or user removes its picks" do
    game = Game.create!(cfbd_id: 12346)
    user = users(:one)
    game_pick = Pick.create!(game: game, user: user)
    user_pick = Pick.create!(game: Game.create!(cfbd_id: 12347), user: user)

    game.destroy!
    assert_not Pick.exists?(game_pick.id)

    user.destroy!
    assert_not Pick.exists?(user_pick.id)
  end

  test "a pick accepts either team in its game" do
    away = Team.create!(cfbd_id: 12348, school: "Away")
    home = Team.create!(cfbd_id: 12349, school: "Home")
    game = Game.create!(cfbd_id: 12350, away: away, home: home)
    pick = Pick.create!(game: game, user: users(:one), team: away)

    assert pick.update(team: home)
    assert_equal home, pick.reload.team
  end

  test "a pick rejects a team outside its game without changing the saved selection" do
    away = Team.create!(cfbd_id: 12351, school: "Away")
    home = Team.create!(cfbd_id: 12352, school: "Home")
    unrelated = Team.create!(cfbd_id: 12353, school: "Unrelated")
    game = Game.create!(cfbd_id: 12354, away: away, home: home)
    pick = Pick.create!(game: game, user: users(:one), team: away)

    assert_not pick.update(team: unrelated)
    assert_includes pick.errors[:team], "must be playing in the game"
    assert_equal away, pick.reload.team
  end

  test "a pick can remain unpicked when the matchup is TBD" do
    game = Game.create!(cfbd_id: 12355)
    pick = Pick.create!(game: game, user: users(:one))

    assert_nil pick.reload.team
  end

  test "locked and open scopes follow game kickoff including unknown starts" do
    travel_to Time.zone.local(2026, 11, 21, 12) do
      picks = [ 1.hour.from_now, Time.current, 1.hour.ago, nil ].each_with_index.map do |start, index|
        game = Game.create!(cfbd_id: 12400 + index, start: start)
        Pick.create!(game: game, user: users(:one))
      end

      assert_equal picks.values_at(1, 2).map(&:id), Pick.locked.order(:id).pluck(:id)
      assert_equal picks.values_at(0, 3).map(&:id), Pick.open.order(:id).pluck(:id)
      assert picks[1].locked?
      assert picks[3].open?
    end
  end

  test "late picks and changed selections store correctness for a settled game" do
    away = Team.create!(cfbd_id: 12356)
    home = Team.create!(cfbd_id: 12357)
    game = Game.create!(cfbd_id: 12358, away: away, home: home, completed: true, away_points: 21, home_points: 14)
    pick = Pick.create!(game: game, user: users(:one), team: away)

    assert_equal true, pick.reload.correct
    pick.update!(team: home)
    assert_equal false, pick.reload.correct
    pick.update!(team: nil)
    assert_equal false, pick.reload.correct
    pick.update!(team: away)
    assert_equal true, pick.reload.correct
    assert_equal false, Pick.create!(game: game, user: users(:two)).reload.correct
  end

  test "picks created before a winner is known remain pending" do
    game = Game.create!(cfbd_id: 12359, completed: true, away_points: 21, home_points: 14)

    assert_nil Pick.create!(game: game, user: users(:one)).reload.correct
  end
end
