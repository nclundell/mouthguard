require "test_helper"

class MyPicksTest < ActionDispatch::IntegrationTest
  setup do
    @away = Team.create!(cfbd_id: Team.maximum(:cfbd_id).to_i + 1, school: "Away School",
                         logos: [ "https://example.com/logos-dark/48/away.png", "https://example.com/logos/48/away.png" ])
    @home = Team.create!(cfbd_id: @away.cfbd_id + 1, school: "Home School",
                         logos: [ "https://example.com/logos/48/home.png" ])
    @game = Game.create!(cfbd_id: Game.maximum(:cfbd_id).to_i + 1, season: Current.season,
                         away: @away, home: @home, notes: "New Bowl", start: 1.day.from_now)
    @other_user = users(:two)
    @user = users(:one)
    sign_in_as @user
  end

  test "only own current-season picks are displayed with both teams and logos" do
    other_pick = Pick.create!(user: @other_user, game: @game, team: @home)
    old_game = Game.create!(cfbd_id: @game.cfbd_id + 1, season: Current.season - 1,
                            notes: "Old Bowl", away: @away, home: @home)
    Pick.create!(user: @user, game: old_game, team: @away)

    assert_not @user.picks.exists?(game: @game)
    assert_no_difference "@other_user.picks.count" do
      get my_picks_path
    end

    assert_response :success
    pick = @user.picks.find_by!(game: @game)
    assert_select "main h1", text: "My Picks"
    assert_select "main article", count: 1 do
      assert_select "h2", text: "New Bowl"
      assert_select "form[action=?]", my_pick_path(pick), count: 1 do
        assert_select "button[name=team_id][value=?][class~='border-2'][class~='border-transparent'][class~='hover:border-pine-600'][class~='dark:hover:border-pine-400']", @away.id.to_s, text: /Away School/
        assert_select "button[name=team_id][value=?][class~='border-2'][class~='border-transparent']", @home.id.to_s, text: /Home School/
      end
      assert_select "img[src='https://example.com/logos/48/away.png'][class~='dark:hidden']"
      assert_select "img[src='https://example.com/logos-dark/48/away.png'][class~='dark:block']"
      assert_select "img[src='https://example.com/logos/48/home.png']", count: 1
    end
    assert_select "main form[action=?]", my_pick_path(other_pick), count: 0
    assert_select "main", text: /Old Bowl/, count: 0
    assert_equal 1, @user.picks.where(game: @game).count
  end

  test "own pick can be selected and changed before kickoff" do
    get my_picks_path
    pick = @user.picks.find_by!(game: @game)

    patch my_pick_path(pick), params: { team_id: @away.id }
    assert_redirected_to my_picks_path
    assert_equal @away, pick.reload.team

    patch my_pick_path(pick), params: { team_id: @home.id }
    assert_redirected_to my_picks_path
    assert_equal @home, pick.reload.team
    follow_redirect!
    assert_select "button[name=team_id][value=?][aria-pressed=true][class~='border-2'][class~='border-pine-700'][class~='dark:border-pine-400']", @home.id.to_s
    assert_select "button.relative[name=team_id][value=?][aria-pressed=true] > span.absolute.right-2.top-2[role=img][aria-label='Picked'] svg[aria-hidden=true]", @home.id.to_s, count: 1
    assert_select "button.relative[name=team_id][value=?][aria-pressed=false] > span[aria-label='Picked']", @away.id.to_s, count: 0
  end

  test "another user's pick and an unrelated team cannot be selected" do
    foreign_pick = Pick.create!(user: @other_user, game: @game, team: @home)
    unrelated = Team.create!(cfbd_id: @home.cfbd_id + 1, school: "Unrelated")
    own_pick = Pick.create!(user: @user, game: @game, team: @away)

    patch my_pick_path(foreign_pick), params: { team_id: @away.id }
    assert_response :not_found
    assert_equal @home, foreign_pick.reload.team

    patch my_pick_path(own_pick), params: { team_id: unrelated.id }
    assert_response :unprocessable_entity
    assert_equal @away, own_pick.reload.team
  end

  test "a nonexistent team cannot replace a saved pick" do
    pick = Pick.create!(user: @user, game: @game, team: @away)
    missing_team_id = Team.maximum(:id) + 1

    patch my_pick_path(pick), params: { team_id: missing_team_id }

    assert_response :unprocessable_entity
    assert_equal @away, pick.reload.team
  end

  test "past-season picks cannot be edited" do
    old_game = Game.create!(cfbd_id: @game.cfbd_id + 1, season: Current.season - 1,
                            away: @away, home: @home, start: 1.day.from_now)
    pick = Pick.create!(user: @user, game: old_game, team: @away)

    patch my_pick_path(pick), params: { team_id: @home.id }

    assert_response :not_found
    assert_equal @away, pick.reload.team
  end

  test "past kickoff locks the card and prevents editing" do
    pick = Pick.create!(user: @user, game: @game, team: @away)
    @game.update!(start: 1.minute.ago)

    patch my_pick_path(pick), params: { team_id: @home.id }

    assert_response :not_found
    assert_equal @away, pick.reload.team
    get my_picks_path
    assert_select "main article button[name=team_id]", count: 0
    assert_select "main article div[class~='border-2'][class~='border-pine-700'][class~='dark:border-pine-400']", text: /Away School/
    assert_select "main article div[class~='border-2'][class~='border-transparent']", text: /Home School/
    assert_select "main article div.relative[class~='border-pine-700'] > span.absolute.right-2.top-2[role=img][aria-label='Picked'] svg[aria-hidden=true]", count: 1
    assert_select "main article div.relative[class~='border-transparent'] > span[aria-label='Picked']", count: 0
    assert_select "main article span[role=img][aria-label='Picks locked'] svg[aria-hidden=true]", count: 1
    assert_select "main article", text: /Picks locked/, count: 0
  end

  test "kickoff at the current time prevents editing" do
    pick = Pick.create!(user: @user, game: @game, team: @away)
    @game.update!(start: Time.current)

    patch my_pick_path(pick), params: { team_id: @home.id }

    assert_response :not_found
    assert_equal @away, pick.reload.team
  end

  test "rescheduled kickoff locks a pick after the picks page was loaded" do
    get my_picks_path
    pick = @user.picks.find_by!(game: @game)
    @game.update!(start: 1.minute.ago)

    patch my_pick_path(pick), params: { team_id: @home.id }

    assert_response :not_found
    assert_nil pick.reload.team
  end

  test "a team removed from the matchup after page load cannot be selected" do
    get my_picks_path
    pick = @user.picks.find_by!(game: @game)
    @game.update!(home: nil)

    patch my_pick_path(pick), params: { team_id: @home.id }

    assert_response :unprocessable_entity
    assert_nil pick.reload.team
  end

  test "unknown kickoff allows known teams and an unpicked team" do
    @game.update!(start: nil, home: nil)
    get my_picks_path
    pick = @user.picks.find_by!(game: @game)
    assert_select "main article", text: /TBD/
    assert_select "main article button[name=team_id]", count: 1
    assert_select "main article div[class~='border-2'][class~='border-transparent']", text: /TBD/

    patch my_pick_path(pick), params: { team_id: "" }
    assert_redirected_to my_picks_path
    assert_nil pick.reload.team
    patch my_pick_path(pick), params: { team_id: @away.id }
    assert_redirected_to my_picks_path
    assert_equal @away, pick.reload.team
  end

  test "picks require sign in" do
    sign_out
    get my_picks_path
    assert_redirected_to new_session_path

    pick = Pick.create!(user: @user, game: @game)
    patch my_pick_path(pick), params: { team_id: @home.id }
    assert_redirected_to new_session_path
    assert_nil pick.reload.team
  end
end
