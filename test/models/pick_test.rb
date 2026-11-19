require "test_helper"

class PickTest < ActiveSupport::TestCase
  test "persists an unpicked game and associates it with its user" do
    game = Game.create!(cfbd_id: 12345)
    user = users(:one)

    pick = Pick.create!(game: game, user: user, season: 2026)

    assert_nil pick.reload.team
    assert_nil pick.correct
    assert_equal 2026, pick.season
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
end
