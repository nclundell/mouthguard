require "test_helper"

class GameShowTest < ActionDispatch::IntegrationTest
  test "subscribes to the game stream and renders a replaceable hero" do
    game = Game.create!(cfbd_id: 92_013)
    sign_in_as users(:one)

    get game_path(game)

    assert_response :success
    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']", count: 1 do |sources|
      assert_equal game.to_gid_param, Turbo.signed_stream_verifier.verified(sources.first["signed-stream-name"])
    end
    assert_select "[data-picks-layout] > section#game_hero_#{game.id}[aria-labelledby='matchup-title']", count: 1
  end

  test "future game hides picks and picker identities in desktop panels" do
    away = Team.create!(cfbd_id: 92_001, school: "Secret Away")
    home = Team.create!(cfbd_id: 92_002, school: "Secret Home")
    game = Game.create!(cfbd_id: 92_003, away: away, home: home, start: 1.day.from_now)
    users(:one).update!(display_name: "Hidden Picker")
    Pick.create!(game: game, user: users(:one), team: away)
    sign_in_as users(:two)

    get game_path(game)

    assert_response :success
    assert_select "[data-picks-side='away'], [data-picks-side='home']", count: 2 do
      assert_select "p", text: "Picks hidden until kickoff", count: 2
      assert_select "ul", count: 0
    end
    assert_select "[data-picks-side='away'][aria-label='Away picks'][class~='hidden'][class~='lg:block']", count: 1
    assert_select "[data-picks-side='home'][aria-label='Home picks'][class~='hidden'][class~='lg:block']", count: 1
    assert_select "[data-picks-side] h2", count: 0
    assert_select "[data-picks-side]", text: /Hidden Picker|Secret Away|Secret Home|one@example.com/, count: 0
    assert_select "[data-mobile-picks]", count: 0
    assert_select "[data-matchup]", count: 1
  end

  test "unknown kickoff also hides picks" do
    away = Team.create!(cfbd_id: 92_004, school: "Unknown Away")
    game = Game.create!(cfbd_id: 92_005, away: away, start: nil)
    users(:one).update!(display_name: "Unknown Picker")
    Pick.create!(game: game, user: users(:one), team: away)
    sign_in_as users(:two)

    get game_path(game)

    assert_select "[data-picks-side] p", text: "Picks hidden until kickoff", count: 2
    assert_select "[data-picks-side] ul", count: 0
    assert_select "[data-picks-side]", text: /Unknown Picker/, count: 0
    assert_select "[data-picks-side='away'][aria-label='Away picks'][class~='hidden'][class~='lg:block']", count: 1
    assert_select "[data-picks-side='home'][aria-label='Home picks'][class~='hidden'][class~='lg:block']", count: 1
    assert_select "[data-mobile-picks]", count: 0
  end

  test "locked game groups selected users by side in desktop panels" do
    away = Team.create!(cfbd_id: 92_006, school: "Away School")
    home = Team.create!(cfbd_id: 92_007, school: "Home School")
    game = Game.create!(cfbd_id: 92_008, away: away, home: home, start: 1.hour.ago)
    users(:one).update!(display_name: "Away Fan")
    users(:two).update!(display_name: "Home Fan")
    Pick.create!(game: game, user: users(:one), team: away)
    Pick.create!(game: game, user: users(:two), team: home)
    sign_in_as users(:one)

    get game_path(game)

    assert_response :success
    assert_select "[data-picks-layout][class*='grid-cols-1'][class*='lg:grid-cols-']" do
      assert_select "> [data-picks-side='away'][aria-label='Away picks'][class~='hidden'][class~='lg:block']:first-child", count: 1
      assert_select "> section[aria-labelledby='matchup-title'][class*='rounded-2xl'][class*='border'][class*='bg-white']:nth-child(2)" do
        assert_select "> [data-matchup-header]:first-child + [data-matchup-content]", count: 1
        assert_select "> [data-matchup-header] > #matchup-title", count: 1
        assert_select "> [data-matchup-header] > [data-kickoff]", count: 1
        assert_select "> [data-matchup-content] [data-matchup]", count: 1
        assert_select "[data-picks-side]", count: 0
      end
      assert_select "> [data-picks-side='home'][aria-label='Home picks'][class~='hidden'][class~='lg:block']:last-child", count: 1
      assert_select "[data-mobile-picks]", count: 0
    end
    assert_select "[data-picks-side] h2", count: 0
    assert_select "[data-picks-side='away'] ul li", text: "Away Fan", count: 1
    assert_select "[data-picks-side='home'] ul li", text: "Home Fan", count: 1
    assert_select "[data-picks-side] ul li[class~='bg-sky-300'][class~='text-sky-950'][class~='dark:bg-amber-200'][class~='dark:text-amber-950'][class~='shadow-md'][class~='dark:shadow-black/30']", count: 2
    assert_select "[data-picks-side] ul li[class~='aspect-square'][class~='w-full'][class~='max-w-32'][class~='mx-auto']", count: 2
    assert_select "[data-picks-side] ul li[class~='flex'][class~='items-center'][class~='justify-center']", count: 2
    assert_select "[data-picks-side] ul li[class~='-rotate-1'][class~='odd:rotate-1'][class~='text-center'][class~='text-lg']", count: 2
    assert_select "[data-picks-side] ul li[class~=\"font-['Permanent_Marker']\"]", count: 2
    assert_select "[data-picks-side] ul li[style]", count: 0
    assert_select "[data-picks-side='away']", text: /Home Fan/, count: 0
    assert_select "[data-picks-side='home']", text: /Away Fan/, count: 0
    assert_select "[data-picks-side] p", text: "Picks hidden until kickoff", count: 0
    assert_select "[data-mobile-picks]", count: 0
  end

  test "picker note font is referenced by the served stylesheet and available locally" do
    font_url = ActionController::Base.helpers.asset_path("permanent_marker/PermanentMarker-Regular.ttf")

    get ActionController::Base.helpers.asset_path("application.css")

    assert_response :success
    assert_includes response.body, "url(\"#{font_url}\")"
    assert_includes response.body, "font-display: swap"

    get font_url

    assert_response :success
    assert_equal "font/ttf", response.media_type
  end

  test "locked game without selections shows empty states on both sides" do
    game = Game.create!(cfbd_id: 92_009, start: 1.hour.ago)
    sign_in_as users(:one)

    get game_path(game)

    assert_select "[data-picks-side] p", text: "No picks yet", count: 2
    assert_select "[data-picks-side] ul", count: 0
    assert_select "[data-picks-side='away'][aria-label='Away picks'][class~='hidden'][class~='lg:block']", count: 1
    assert_select "[data-picks-side='home'][aria-label='Home picks'][class~='hidden'][class~='lg:block']", count: 1
    assert_select "[data-mobile-picks]", count: 0
  end

  test "locked game ignores unselected picks and leaves the other side empty" do
    away = Team.create!(cfbd_id: 92_010, school: "Away School")
    home = Team.create!(cfbd_id: 92_011, school: "Home School")
    game = Game.create!(cfbd_id: 92_012, away: away, home: home, start: 1.hour.ago)
    users(:one).update!(display_name: "Away Fan")
    users(:two).update!(display_name: "No Selection Fan")
    Pick.create!(game: game, user: users(:one), team: away)
    Pick.create!(game: game, user: users(:two), team: nil)
    sign_in_as users(:one)

    get game_path(game)

    assert_select "[data-picks-side='away'] ul li", text: "Away Fan", count: 1
    assert_select "[data-picks-side='home'] p", text: "No picks yet"
    assert_select "[data-picks-side]", text: /No Selection Fan/, count: 0
    assert_select "[data-mobile-picks]", count: 0
  end

  test "matchup shows bowl title, teams, box-score totals, kickoff and broadcast" do
    away = Team.create!(cfbd_id: 91_001, school: "Away School",
                        logos: [ "https://example.com/logos-dark/48/away.png", "https://example.com/logos/48/away.png" ])
    home = Team.create!(cfbd_id: 91_002, school: "Home School", logos: [ "https://example.com/logos/48/home.png" ])
    kickoff = Time.zone.local(2026, 12, 20, 18, 30)
    game = Game.create!(cfbd_id: 91_003, notes: "Championship Bowl", away: away, home: home,
                        away_points: 0, home_points: 42, start: kickoff, tv: "ESPN")
    sign_in_as users(:one)

    get game_path(game)

    assert_response :success
    assert_select "main h1", text: "Championship Bowl", count: 1
    assert_select "main h1", count: 1
    assert_equal 1, css_select("main").text.scan("Championship Bowl").length
    assert_select "[data-team='away'] h2", text: "Away School"
    assert_select "[data-team='home'] h2", text: "Home School"
    assert_select "[data-team] [data-score]", count: 0
    assert_select "[data-matchup] table[aria-label='Box score']" do
      assert_select "thead th[aria-label='Total']", text: "T"
      assert_select "tbody tr:first-child td:last-child", text: "0"
      assert_select "tbody tr:last-child td:last-child", text: "42"
    end
    assert_select "img[src='https://example.com/logos/48/away.png'][alt='']", count: 1
    assert_select "img[src='https://example.com/logos-dark/48/away.png'][alt='']", count: 1
    assert_select "img[src='https://example.com/logos/48/home.png'][alt='']", count: 1
    assert_select "h1#matchup-title + time[data-kickoff][datetime=?][data-controller='local-time']", kickoff.iso8601
    assert_select "[data-matchup] table + [data-game-status]", text: "Upcoming"
    assert_select "[data-broadcast]", text: "ESPN"
    assert_select "[data-matchup] [data-broadcast]", count: 0
    assert_select "[data-kickoff]", count: 1
    assert_select "[data-game-status]", count: 1
    assert_select "[data-matchup]", text: /VS/, count: 0
  end

  test "pregame and missing matchup data have readable fallbacks" do
    game = Game.create!(cfbd_id: 91_004)
    sign_in_as users(:one)

    get game_path(game)

    assert_response :success
    assert_select "main h1", text: "Game", count: 1
    assert_select "main h1", count: 1
    assert_select "[data-team='away']", text: /TBD/
    assert_select "[data-team='home']", text: /TBD/
    assert_select "[data-matchup] > span", text: "VS"
    assert_select "[data-matchup] table", count: 0
    assert_select "[data-matchup] span + [data-game-status]", text: "Upcoming"
    assert_select "[data-score]", count: 0
    assert_select "time", count: 0
    assert_select "h1#matchup-title + [data-kickoff]", text: "Kickoff TBD"
    assert_select "[data-broadcast]", count: 0
    assert_select "img", count: 0
  end

  test "matchup displays four quarters and total points in a box score" do
    away = Team.create!(cfbd_id: 91_011, school: "Away School", abbreviation: "AWY")
    home = Team.create!(cfbd_id: 91_012, school: "Home School", abbreviation: "HME")
    game = Game.create!(cfbd_id: 91_013, away: away, home: home,
                        away_line_scores: [ 7, 0, 3, 10 ], home_line_scores: [ 0, 7, 7, 3 ],
                        away_points: 20, home_points: 17)
    sign_in_as users(:one)

    get game_path(game)

    assert_response :success
    assert_select "[data-matchup] table[aria-label='Box score']" do
      assert_select "thead th[scope='col']", text: "1"
      assert_select "thead th[scope='col']", text: "2"
      assert_select "thead th[scope='col']", text: "3"
      assert_select "thead th[scope='col']", text: "4"
      assert_select "thead th[scope='col'][aria-label='Total']", text: "T"
      assert_select "tbody tr", count: 2
      assert_select "tbody tr:first-child", text: /AWY\s*7\s*0\s*3\s*10\s*20/
      assert_select "tbody tr:last-child", text: /HME\s*0\s*7\s*7\s*3\s*17/
      assert_select "tbody th[scope='row']", count: 2
    end
    assert_select "[data-team] [data-score]", count: 0
  end

  test "matchup labels overtime and leaves missing periods and points blank with a dash" do
    away = Team.create!(cfbd_id: 91_014, school: "Away School")
    game = Game.create!(cfbd_id: 91_015, away: away,
                        away_line_scores: [ 7, 7, 0, 7, 3, 2 ],
                        home_line_scores: [ 0, 0, 7, 14, 3 ], away_points: 26)
    sign_in_as users(:one)

    get game_path(game)

    assert_response :success
    assert_select "[data-matchup] table" do
      assert_select "thead th[scope='col']", text: "OT"
      assert_select "thead th[scope='col']", text: "2OT"
      assert_select "tbody tr:first-child", text: /Away School\s*7\s*7\s*0\s*7\s*3\s*2\s*26/
      assert_select "tbody tr:last-child", text: /TBD\s*0\s*0\s*7\s*14\s*3\s*–\s*–/
    end
    assert_select "[data-score]", count: 0
  end

  test "scores without line scores remain visible as box-score totals" do
    game = Game.create!(cfbd_id: 91_016, away_points: 21, home_points: 17)
    sign_in_as users(:one)

    get game_path(game)

    assert_select "[data-matchup] table[aria-label='Box score']" do
      assert_select "thead th[aria-label='Total']", text: "T"
      assert_select "tbody tr:first-child td:last-child", text: "21"
      assert_select "tbody tr:last-child td:last-child", text: "17"
    end
    assert_select "[data-team] [data-score]", count: 0
  end

  test "live games show period and clock beneath matchup and partial scores do not masquerade as a result" do
    game = Game.create!(cfbd_id: 91_005, start: 1.hour.ago, completed: false,
                        status: "in_progress", period: "2", clock: "08:34", away_points: 7)
    sign_in_as users(:one)

    get game_path(game)

    assert_select "[data-matchup] span + [data-game-status]", text: "Live · Period 2 · 08:34"
    assert_select "[data-matchup] > span", text: "VS"
    assert_select "[data-score]", count: 0
  end

  test "live games without period or clock show live beneath box score" do
    game = Game.create!(cfbd_id: 91_017, start: 1.hour.ago, status: "in_progress",
                        away_points: 7, home_points: 3)
    sign_in_as users(:one)

    get game_path(game)

    assert_select "[data-matchup] table + [data-game-status]", text: "Live"
  end

  test "live games with only a period show it beneath box score" do
    game = Game.create!(cfbd_id: 91_018, start: 1.hour.ago, status: "in_progress",
                        period: "2", away_points: 7, home_points: 3)
    sign_in_as users(:one)

    get game_path(game)

    assert_select "[data-matchup] table + [data-game-status]", text: "Live · Period 2"
  end

  test "live games with only a clock show it beneath box score" do
    game = Game.create!(cfbd_id: 91_019, start: 1.hour.ago, status: "in_progress",
                        clock: "08:34", away_points: 7, home_points: 3)
    sign_in_as users(:one)

    get game_path(game)

    assert_select "[data-matchup] table + [data-game-status]", text: "Live · 08:34"
  end

  test "completed games show final status" do
    game = Game.create!(cfbd_id: 91_006, start: 1.day.ago, completed: true,
                        away_points: 21, home_points: 17)
    sign_in_as users(:one)

    get game_path(game)

    assert_select "[data-matchup] table + [data-game-status]", text: "Final"
    assert_select "[data-matchup] tbody tr:first-child td:last-child", text: "21"
    assert_select "[data-matchup] tbody tr:last-child td:last-child", text: "17"
    assert_select "[data-team] [data-score]", count: 0
  end

  test "completed status shows final when completed flag is false" do
    game = Game.create!(cfbd_id: 91_007, start: 1.day.ago, completed: false, status: "completed")
    sign_in_as users(:one)

    get game_path(game)

    assert_response :success
    assert_select "[data-matchup] span + [data-game-status]", text: "Final"
  end

  test "malformed logo entries are ignored when selecting images and fallback" do
    away = Team.create!(cfbd_id: 91_008, school: "Away School",
                        logos: [ nil, "https://example.com/logos-dark/48/away.png", 42, "https://example.com/logos/48/away.png" ])
    home = Team.create!(cfbd_id: 91_009, school: "Home School", logos: [ 42, "", nil ])
    game = Game.create!(cfbd_id: 91_010, away: away, home: home)
    sign_in_as users(:one)

    get game_path(game)

    assert_response :success
    assert_select "[data-team='away'] img[src='https://example.com/logos/48/away.png']", count: 1
    assert_select "[data-team='away'] img[src='https://example.com/logos-dark/48/away.png']", count: 1
    assert_select "[data-team='home'] img", count: 0
    assert_select "[data-team='home'] div[aria-hidden='true']", text: "H"
  end

  test "missing game returns not found" do
    sign_in_as users(:one)

    get game_path(Game.maximum(:id).to_i + 1)

    assert_response :not_found
  end

  test "anonymous visitor is redirected to sign in" do
    get game_path(1)

    assert_redirected_to new_session_path
  end
end
