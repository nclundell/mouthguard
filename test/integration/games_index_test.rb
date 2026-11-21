require "test_helper"

class GamesIndexTest < ActionDispatch::IntegrationTest
  test "current-season games link to their pages with matchup details" do
    away = Team.create!(cfbd_id: Team.maximum(:cfbd_id).to_i + 1, school: "Away School",
                        logos: [ "https://example.com/logos-dark/48/away.png", "https://example.com/logos/48/away.png" ])
    home = Team.create!(cfbd_id: away.cfbd_id + 1, school: "Home School", logos: [ "https://example.com/logos/48/home.png" ])
    start = Time.zone.local(2025, 12, 20, 18, 30)
    game = Game.create!(cfbd_id: Game.maximum(:cfbd_id).to_i + 1, season: Current.season,
                        away: away, home: home, away_points: 0, home_points: 42,
                        notes: "Championship", start: start, tv: "ESPN")
    other = Game.create!(cfbd_id: game.cfbd_id + 1, season: Current.season - 1, notes: "Old Bowl")
    sign_in_as users(:one)

    get games_path

    assert_response :success
    assert_select "main a.flex.flex-col.h-full[href=?]", game_path(game), count: 1 do
      assert_select "h2.text-center", text: "Championship"
      assert_select "div.mt-auto", count: 1 do
        assert_select "div.grid.grid-cols-2", count: 1 do
          assert_select "div.flex.flex-col.items-center", count: 2
          assert_select "div.flex.flex-col.items-center:first-child" do
            assert_select "img[src='https://example.com/logos/48/away.png'][alt=''][class~='block'][class~='dark:hidden']", count: 1
            assert_select "img[src='https://example.com/logos-dark/48/away.png'][alt=''][class~='hidden'][class~='dark:block'] + span", text: "Away School"
            assert_select "span + span", text: "0"
          end
          assert_select "div.flex.flex-col.items-center:last-child" do
            assert_select "img[src='https://example.com/logos/48/home.png'][alt=''][class~='size-10']:not([class~='dark:hidden']) + span", text: "Home School"
            assert_select "img[src='https://example.com/logos/48/home.png']", count: 1
            assert_select "span + span", text: "42"
          end
        end
        assert_select "time.text-center[data-controller='local-time'][datetime=?]", start.iso8601,
                      text: /Dec 20, 2025 at 6:30 PM/
        assert_select "span.text-center", text: "ESPN", count: 1
      end
    end
    assert_select "main a[href=?]", game_path(other), count: 0
    assert_select "main", text: /Old Bowl/, count: 0
  end

  test "teams with only a dark logo keep that logo visible in both modes" do
    team = Team.create!(cfbd_id: Team.maximum(:cfbd_id).to_i + 1, school: "Dark Only",
                        logos: [ "https://example.com/logos-dark/48/only.png" ])
    game = Game.create!(cfbd_id: Game.maximum(:cfbd_id).to_i + 1, season: Current.season, away: team)
    sign_in_as users(:one)

    get games_path

    assert_response :success
    assert_select "main a[href=?]", game_path(game), count: 1 do
      assert_select "img[src='https://example.com/logos-dark/48/only.png']:not([class~='dark:hidden']) + span",
                    text: "Dark Only"
      assert_select "img[src='https://example.com/logos-dark/48/only.png']", count: 1
    end
  end

  test "games without optional details still render a useful link" do
    game = Game.create!(cfbd_id: Game.maximum(:cfbd_id).to_i + 1, season: Current.season, notes: "  ")
    sign_in_as users(:one)

    get games_path

    assert_response :success
    assert_select "main a.flex.flex-col.h-full[href=?]", game_path(game), count: 1 do
      assert_select "h2.text-center", text: "Game"
      assert_select "div.mt-auto", count: 1 do
        assert_select "div.grid.grid-cols-2", count: 1 do
          assert_select "div.flex.flex-col.items-center", count: 2
          assert_select "div.flex.flex-col.items-center:first-child > span", text: "TBD"
          assert_select "div.flex.flex-col.items-center:last-child > span", text: "TBD"
          assert_select "span + span", count: 0
        end
        assert_select "time", count: 0
        assert_select "span.text-center", count: 0
      end
      assert_select "img", count: 0
    end
  end

  test "anonymous visitors are redirected to sign in" do
    get games_path

    assert_redirected_to new_session_path
  end
end
