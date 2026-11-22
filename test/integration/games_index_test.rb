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
    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']", count: 1 do |sources|
      assert_equal "games", Turbo.signed_stream_verifier.verified(sources.first["signed-stream-name"])
    end
    assert_select "main a#game_#{game.id}.flex.flex-col.h-full[href=?]", game_path(game), count: 1 do
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

  test "filters offer unique current-season titles and teams with unchecked options and card IDs" do
    away = Team.create!(cfbd_id: Team.maximum(:cfbd_id).to_i + 1, school: "Away School", conference: "Atlantic")
    home = Team.create!(cfbd_id: away.cfbd_id + 1, school: "Home School", conference: "Pacific")
    twin = Team.create!(cfbd_id: home.cfbd_id + 1, school: "Home School", conference: "Pacific")
    first = Game.create!(cfbd_id: Game.maximum(:cfbd_id).to_i + 1, season: Current.season,
                         notes: "Shared Bowl", away: away, home: home)
    second = Game.create!(cfbd_id: first.cfbd_id + 1, season: Current.season,
                          notes: "Shared Bowl", away: away, home: twin)
    unnamed = Game.create!(cfbd_id: second.cfbd_id + 1, season: Current.season, notes: " ")
    Game.create!(cfbd_id: unnamed.cfbd_id + 1, season: Current.season - 1,
                 notes: "Old Bowl", away: Team.create!(cfbd_id: twin.cfbd_id + 1, school: "Old Team", conference: "Old Conference"))
    sign_in_as users(:one)

    assert_no_difference "Game.count" do
      get games_path
    end

    assert_response :success
    assert_select "[data-controller='games-filter'][data-action*='keydown.esc->games-filter#close']", count: 1
    assert_select "[data-games-filter-target='controls'][class~='hidden'][class~='sm:flex']", count: 1
    assert_select "[data-games-filter-target='cards']", count: 1
    { "bowl" => "bowls", "team" => "teams", "conference" => "conferences" }.each do |axis, plural|
      assert_select "label[for='games-#{axis}-search']", text: axis.capitalize, count: 1
      assert_select "input#games-#{axis}-search[type=search][placeholder='Search #{plural}'][aria-label='Search #{plural}'][aria-controls='games-#{axis}-options'][aria-expanded=false][class~='w-40'][data-action*='input->games-filter#search']", count: 1
      assert_select "#games-#{axis}-options[hidden][data-games-filter-target='#{axis}Dropdown']", count: 1
      assert_select "[data-games-filter-target='#{axis}Count']", text: "All"
      assert_select "button[aria-label='Clear #{axis} filter'][disabled][hidden].hidden", count: 1
      assert_select "[data-games-filter-target='#{axis}Option'] input[checked]", count: 0
    end
    assert_select "[data-games-filter-target='bowlOption']", text: "Shared Bowl", count: 1
    assert_select "[data-games-filter-target='bowlOption'] input[value='Game']", count: 1
    assert_select "[data-games-filter-target='bowlOption']", text: "Old Bowl", count: 0
    assert_select "[data-games-filter-target='teamOption'] input[value='#{away.id}']", count: 1
    [ home, twin ].each do |team|
      assert_select "[data-games-filter-target='teamOption']", text: "Home School (#{team.id})", count: 1
      assert_select "[data-games-filter-target='teamOption'] input[value='#{team.id}']", count: 1
    end
    assert_select "[data-games-filter-target='teamOption']", text: "Old Team", count: 0
    assert_select "[data-games-filter-target='teamOption'][hidden] input[type=checkbox][data-action='change->games-filter#update']", count: 3
    %w[Atlantic Pacific].each do |conference|
      assert_select "[data-games-filter-target='conferenceOption'] input[value='#{conference}']", count: 1
    end
    assert_select "[data-games-filter-target='conferenceOption'] input[value='Old Conference']", count: 0
    assert_select "[data-games-filter-target='conferenceOption'][hidden] input[type=checkbox][data-action='change->games-filter#update']", count: 2
    assert_select "a#game_#{first.id}[data-games-filter-target=gameCard][data-bowl-title='Shared Bowl'][data-away-team-id='#{away.id}'][data-away-team-school='Away School'][data-away-team-conference='Atlantic'][data-home-team-id='#{home.id}'][data-home-team-school='Home School'][data-home-team-conference='Pacific']", count: 1
    assert_select "a#game_#{second.id}[data-games-filter-target=gameCard][data-bowl-title='Shared Bowl'][data-away-team-id='#{away.id}'][data-home-team-id='#{twin.id}']", count: 1
    assert_select "a#game_#{unnamed.id}[data-games-filter-target=gameCard][data-bowl-title='Game']", count: 1
    assert_select "a#game_#{unnamed.id}[data-away-team-id]:not([data-away-team-id=''])", count: 0
    assert_select "a#game_#{unnamed.id}[data-away-team-conference=''][data-home-team-conference='']", count: 1
  end

  test "fallback Team labels are disambiguated against actual Team schools" do
    unnamed = Team.create!(cfbd_id: Team.maximum(:cfbd_id).to_i + 1, school: "")
    named = Team.create!(cfbd_id: unnamed.cfbd_id + 1, school: "Team")
    game = Game.create!(cfbd_id: Game.maximum(:cfbd_id).to_i + 1, season: Current.season,
                        away: unnamed, home: named)
    sign_in_as users(:one)

    get games_path

    [ unnamed, named ].each do |team|
      assert_select "[data-games-filter-target='teamOption']", text: "Team (#{team.id})", count: 1
      assert_select "a#game_#{game.id}[data-#{team == unnamed ? 'away' : 'home'}-team-id='#{team.id}'][data-#{team == unnamed ? 'away' : 'home'}-team-school='Team']", count: 1
    end
  end

  test "blank conferences do not become filter options" do
    team = Team.create!(cfbd_id: Team.maximum(:cfbd_id).to_i + 1, school: "Independent", conference: "  ")
    game = Game.create!(cfbd_id: Game.maximum(:cfbd_id).to_i + 1, season: Current.season, home: team)
    sign_in_as users(:one)

    get games_path

    assert_select "[data-games-filter-target='conferenceOption']", count: 0
    assert_select "a#game_#{game.id}[data-home-team-conference=''][data-away-team-conference='']", count: 1
  end

  test "replacement card exposes updated title and team data" do
    old_team = Team.create!(cfbd_id: Team.maximum(:cfbd_id).to_i + 1, school: "Old Team")
    new_team = Team.create!(cfbd_id: old_team.cfbd_id + 1, school: "New Team", conference: "New Conference")
    game = Game.create!(cfbd_id: Game.maximum(:cfbd_id).to_i + 1, season: Current.season,
                        notes: "Old Bowl", home: old_team)
    game.update!(notes: "New Bowl", home: new_team)

    card = Nokogiri::HTML.fragment(ApplicationController.render(partial: "games/game_card", locals: { game: game }))
    assert_equal "New Bowl", card.at_css("a")["data-bowl-title"]
    assert_equal new_team.id.to_s, card.at_css("a")["data-home-team-id"]
    assert_equal "New Team", card.at_css("a")["data-home-team-school"]
    assert_equal "New Conference", card.at_css("a")["data-home-team-conference"]
  end

  test "anonymous visitors are redirected to sign in" do
    get games_path

    assert_redirected_to new_session_path
  end
end
