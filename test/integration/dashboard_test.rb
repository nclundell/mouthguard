require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  test "scoreboard keeps kickoff chronology while featuring the earliest live game" do
    now = Time.current
    later_live = dashboard_game("Later live", start: now - 1.hour, period: "3", clock: "08:40")
    earliest_live = dashboard_game("Earliest live", start: now - 3.hours, period: "2", clock: "04:12")
    upcoming = dashboard_game("Upcoming", start: now + 1.day)
    final = dashboard_game("Final", start: now - 1.day, completed: true)
    older_final = dashboard_game("Older final", start: now - 2.days, completed: true)
    recent_final = dashboard_game("Recent final", start: now - 2.hours, status: "completed")
    dashboard_game("Other season", start: now - 4.hours, season: Current.season - 1)
    sign_in_as users(:one)

    get root_path

    assert_response :success
    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']", 1 do |sources|
      assert_equal "dashboard_games", Turbo.signed_stream_verifier.verified(sources.first["signed-stream-name"])
    end
    assert_select "[data-controller=game-carousel] [data-game-carousel-target=track] > [data-game-carousel-target=slide]" do |slides|
      assert_equal [older_final, final, earliest_live, recent_final, later_live, upcoming].map { |game| "game_#{game.id}" },
                   slides.map { |slide| slide.at_css("a")["id"] }
      assert_equal [ "game_#{earliest_live.id}" ], slides.select { |slide| slide["data-featured"] == "true" }.map { |slide| slide.at_css("a")["id"] }
      assert slides.all? { |slide| slide["class"].split.include?("self-center") }
      assert slides.all? { |slide| (slide["class"].split & %w[ring-2 ring-pine-700 ring-offset-2 dark:ring-pine-400 dark:ring-offset-neutral-900]).empty? }
    end
    assert_select "#game_#{earliest_live.id} [data-game-status]", text: /Live · Period 2 · 04:12/
    assert_select "#game_#{final.id} [data-game-status]", text: "Final"
    assert_select "#game_#{earliest_live.id}.block:not(.h-full)" do
      assert_select "div.mt-3.flex.items-center.justify-center > div.overflow-x-auto", count: 1
    end
    assert_select "[data-game-carousel-target=slide] [data-games-filter-target]", count: 0
    assert_select "[data-game-carousel-target=slide] span", text: "VS", count: 6
    { earliest_live => "live", later_live => "live", upcoming => "upcoming", final => "final", older_final => "final", recent_final => "final" }.each do |game, status|
      assert_select "#game_#{game.id}[data-scoreboard-status=?][data-scoreboard-kickoff=?]", status, game.start.iso8601
    end
    assert_select "[data-game-carousel-target=context][data-scoreboard-context]", text: /Live now/
    assert_select "button[aria-label='Previous game'][data-action='game-carousel#previous']", 1
    assert_select "button[aria-label='Next game'][data-action='game-carousel#next']", 1
    assert_select "[data-game-carousel-control].absolute.top-1\\/2", count: 2
    assert_select "[aria-hidden=true].pointer-events-none.absolute", count: 2
    assert_select "[data-game-carousel-target=track][tabindex=0][aria-label='Games scoreboard'].overflow-x-auto.py-1", 1
    assert_select "a[href=?]", my_picks_path, text: /My Picks/
    assert_select "a[href=?]", games_path, text: /All games/
    assert_select "a[href=?]", leaders_path, text: /Leaders/
  end

  test "scoreboard focuses next upcoming when no games are live" do
    future = dashboard_game("Next up", start: 1.day.from_now)
    dashboard_game("Later", start: 2.days.from_now)
    unknown = dashboard_game("TBD")
    finished = dashboard_game("Finished", start: 1.day.ago, status: "completed")
    sign_in_as users(:one)

    get root_path

    assert_select "[data-game-carousel-target=slide] a" do |cards|
      assert_equal [ "Finished", "Next up", "Later", "TBD" ], cards.map { |card| card.at_css("h3").text }
    end
    assert_select "[data-featured=true] > #game_#{future.id}", count: 1
    assert_select "#game_#{unknown.id}[data-scoreboard-status=upcoming]:not([data-scoreboard-kickoff])"
    assert_select "#game_#{finished.id}[data-scoreboard-status=final]"
    assert_select "[data-scoreboard-context]", text: /Next up/
  end

  test "scoreboard truncates long bowl names while retaining the full title" do
    name = "A Very Long Bowl Name That Would Otherwise Wrap Across Multiple Lines"
    game = dashboard_game(name, start: 1.day.from_now)
    sign_in_as users(:one)

    get root_path

    assert_select "#game_#{game.id} h3.truncate[title=?]", name, text: name
  end

  test "scoreboard puts unscheduled games last and breaks equal kickoffs by id" do
    kickoff = 1.day.from_now
    first = dashboard_game("First", start: kickoff)
    second = dashboard_game("Second", start: kickoff)
    unknown = dashboard_game("Unknown")
    sign_in_as users(:one)

    get root_path

    assert_select "[data-game-carousel-target=slide] a" do |cards|
      assert_equal [first, second, unknown].map { |game| "game_#{game.id}" }, cards.map { |card| card["id"] }
    end
  end

  test "scoreboard focuses newest final when only completed games remain" do
    dashboard_game("Older final", start: 2.days.ago, completed: true)
    dashboard_game("Newest final", start: 1.day.ago, completed: true)
    dashboard_game("Unknown final", completed: true)
    sign_in_as users(:one)

    get root_path

    assert_select "[data-game-carousel-target=slide] a" do |cards|
      assert_equal [ "Older final", "Newest final", "Unknown final" ], cards.map { |card| card.at_css("h3").text }
    end
    assert_select "[data-featured=true] a", text: /Newest final/, count: 1
  end

  test "replacement card changes scoreboard metadata from live to final" do
    game = dashboard_game("Finishing game", start: 2.hours.ago)
    sign_in_as users(:one)
    get root_path

    assert_select "#game_#{game.id}[data-scoreboard-status=live]"
    game.update!(completed: true)
    card = Nokogiri::HTML.fragment(ApplicationController.render(partial: "dashboard/scoreboard_game", locals: { game: game })).at_css("a")

    assert_equal "game_#{game.id}", card["id"]
    assert_equal "final", card["data-scoreboard-status"]
    assert_equal game.start.iso8601, card["data-scoreboard-kickoff"]
    assert_equal "Final", card.at_css("[data-game-status]").text
  end

  test "scoreboard renders overtime periods and totals without duplicate scores" do
    away = Team.create!(cfbd_id: Team.maximum(:cfbd_id).to_i + 1, school: "Away", abbreviation: "AWY")
    home = Team.create!(cfbd_id: away.cfbd_id + 1, school: "Home", abbreviation: "HME")
    game = dashboard_game("Overtime Bowl", away: away, home: home, completed: true,
                          away_line_scores: [ 7, 0, 3, 10, 3, 2 ], home_line_scores: [ 0, 7, 7, 3, 6 ],
                          away_points: 25, home_points: 23, start: 1.day.ago)
    sign_in_as users(:one)

    get root_path

    assert_select "#game_#{game.id}" do
      assert_select "h3", text: "Overtime Bowl"
      assert_select "table[aria-label='Box score']" do
        assert_select "thead th", text: "OT"
        assert_select "thead th", text: "2OT"
        assert_select "tbody tr:first-child", text: /AWY\s*7\s*0\s*3\s*10\s*3\s*2\s*25/
        assert_select "tbody tr:last-child", text: /HME\s*0\s*7\s*7\s*3\s*6\s*–\s*23/
      end
      assert_select "[data-game-status]", text: "Final"
      assert_select "span.text-lg", count: 0
    end
  end

  test "scoreboard flanks the box score with decorative theme-aware team logos" do
    away = Team.create!(cfbd_id: Team.maximum(:cfbd_id).to_i + 1, school: "Away", abbreviation: "AWY",
                        logos: [ "https://example.com/logos-dark/away.png", "https://example.com/logos/away.png" ])
    home = Team.create!(cfbd_id: away.cfbd_id + 1, school: "Home", abbreviation: "HME",
                        logos: [ "https://example.com/logos/home.png", "https://example.com/logos-dark/home.png" ])
    game = dashboard_game("Logo Bowl", away: away, home: home, away_points: 7, home_points: 10)
    sign_in_as users(:one)

    get root_path

    assert_select "#game_#{game.id} .flex.items-center.justify-center" do |rows|
      row = rows.first
      assert_equal %w[IMG IMG DIV IMG IMG], row.element_children.map(&:name).map(&:upcase)
      assert_equal %w[AWY HME], row.css("table tbody th[scope=row]").map(&:text)
      [ [ "away", 0 ], [ "home", 3 ] ].each do |side, index|
        normal, dark = row.element_children[index, 2]
        assert_equal "https://example.com/logos/#{side}.png", normal["src"]
        assert_includes normal["class"].split, "dark:hidden"
        assert_equal "https://example.com/logos-dark/#{side}.png", dark["src"]
        assert_includes dark["class"].split, "dark:block"
        assert_equal "", normal["alt"]
        assert_equal "", dark["alt"]
      end
    end
  end

  test "scoreboard omits absent logos without placeholders" do
    away = Team.create!(cfbd_id: Team.maximum(:cfbd_id).to_i + 1, school: "Away", logos: [])
    home = Team.create!(cfbd_id: away.cfbd_id + 1, school: "Home",
                        logos: [ "https://example.com/logos/home.png" ])
    game = dashboard_game("One Logo", away: away, home: home)
    sign_in_as users(:one)

    get root_path

    assert_select "#game_#{game.id} .flex.items-center.justify-center" do |rows|
      assert_equal %w[DIV IMG], rows.first.element_children.map(&:name).map(&:upcase)
      assert_equal "VS", rows.first.at_css("div span").text
      assert_equal "https://example.com/logos/home.png", rows.first.at_css("img")["src"]
    end
  end

  test "scoreboard shows totals only or VS with missing teams and line scores" do
    scored = dashboard_game("Scores only", away_points: 0, home_points: 14)
    unknown = dashboard_game("No scores")
    sign_in_as users(:one)

    get root_path

    assert_select "#game_#{scored.id} table[aria-label='Box score']" do
      assert_select "thead th[scope=col]", count: 2
      assert_select "tbody th[scope=row]", text: "TBD", count: 2
      assert_select "tbody tr:first-child td", text: "0"
      assert_select "tbody tr:last-child td", text: "14"
    end
    assert_select "#game_#{unknown.id} span", text: "VS"
    assert_select "#game_#{unknown.id} [data-game-status]", text: "Kickoff TBD"
  end

  test "scoreboard has an empty state when the current season has no games" do
    sign_in_as users(:one)

    get root_path

    assert_select "[data-game-carousel-target=track]", 0
    assert_select "[data-scoreboard-empty]", text: /No games yet/
    assert_select "[data-scoreboard-empty] a[href=?]", games_path
  end

  test "desktop navigation lists picks before games" do
    sign_in_as users(:one)

    get root_path

    assert_response :success
    assert_select "header nav[aria-label='Main navigation'] > a" do |links|
      assert_equal %w[Games Picks Leaders Legends], links.map(&:text)
    end
  end

  test "navbar has mobile sticky classes and remains before main" do
    get root_path

    assert_response :success
    assert_select "body > header[data-controller='navbar-height'].sticky.top-0.z-30[class~='sm:static'] + main", 1
  end

  test "authenticated user sees brand navigation and can sign out" do
    users(:one).update!(display_name: "Pat Example")
    sign_in_as users(:one)

    get root_path

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_select "body.bg-linear-to-b[class~='from-amber-50'][class~='to-[#f5efdf]'][class~='dark:from-neutral-900'][class~='dark:to-neutral-950']", 1
    assert_select "main.bg-linear-to-b", 0
    assert_select "body.dark\\:bg-neutral-950.dark\\:text-neutral-100"
    assert_select "h1.dark\\:text-neutral-100", text: "Dashboard"
    assert_select "header.sticky.top-0.z-30[class~='sm:static'].bg-black.bg-linear-to-b.from-neutral-800.to-black:not(.shadow-md):not([class~='shadow-black/25'])", 1
    assert_select "header.border-b", 0
    assert_select "details > div.bg-black:not(.border):not(.border-neutral-800):not(.bg-linear-to-b):not(.from-neutral-900):not(.to-black):not(.shadow-lg)"
    assert_select "header a.text-neutral-100[class~='hover:text-pine-400']", text: "Mouthguard"
    assert_select "header a[href=?] > svg[data-icon=mouthguard][aria-hidden=true] + span", root_path, text: "Mouthguard", count: 1
    assert_select "header a[href=?] > svg.size-8.text-amber-500[viewBox='0 0 24 24'][fill=currentColor] path[d='M2 5a2 2 0 0 1 4 0v4a6 6 0 0 0 12 0V5a2 2 0 0 1 4 0v4A10 10 0 0 1 2 9V5Z']", root_path, count: 1
    assert_select "h1.border-pine-950.dark\\:border-pine-500", text: "Dashboard"
    assert_select "head script[src*='theme']", 1
    assert_select "header [data-theme-toggle][type=button][role=switch][aria-label='Dark Mode'][title='Toggle dark mode'][aria-checked=false]", 1
    assert_select "header [data-theme-toggle].size-11:not(.w-full):not(.bg-pine-400)[class*='hover:'][class*='focus-visible:']", 1
    assert_select "header [data-theme-toggle] > span", 0
    assert_select "header [data-theme-toggle] > svg[data-theme-icon=off].text-pine-400[aria-hidden=true]:not([hidden]) path[d='M12 3c.132 0 .263 0 .393 0a7.5 7.5 0 0 0 7.92 12.446a9 9 0 1 1 -8.313 -12.454l0 .008']", 1
    assert_select "header [data-theme-toggle] > svg[data-theme-icon=on].text-pine-400[aria-hidden=true][hidden] path[d='M8 12a4 4 0 1 0 8 0a4 4 0 1 0 -8 0']", 1
    assert_select "header > div.flex-wrap > div.items-center.gap-2" do
      assert_select "> [data-theme-toggle]", 1
      assert_select "> div.sm\\:flex > details > summary", 1
      assert_select "> details.sm\\:hidden > summary", 1
    end
    assert_select "header [data-theme-system]", 0
    assert_select "header a[href=?]", root_path, text: "Mouthguard"
    assert_select "header nav[aria-label='Main navigation']", 1
    assert_select "header a", text: "Dashboard", count: 0
    assert_select "details.hidden.sm\\:block[data-close-on-outside]", 1 do
      assert_select "summary.h-11.w-40.border.border-transparent.text-neutral-100[class~='hover:border-pine-500'][class~='hover:bg-neutral-800']:not(.bg-pine-900):not(.bg-pine-950):not([class~='border-pine-900'])[class*='focus-visible:']", text: /Pat Example/
      assert_select "summary > span.min-w-0.flex-1.truncate[title='Pat Example']", text: "Pat Example"
      assert_select "summary > svg:first-child.size-6.shrink-0[aria-hidden=true] path[d='M6.168 18.849a4 4 0 0 1 3.832 -2.849h4a4 4 0 0 1 3.834 2.855']", count: 1
      assert_select "summary > img", count: 0
      assert_select "summary svg[aria-hidden='true'] path[d='M6 9l6 6l6 -6']"
      assert_select "[data-theme-toggle]", 0
      assert_select "div.absolute.w-56 > form > button.w-full.min-h-11.px-3", text: "Sign out"
      assert_select "form[action=?][method=post]", session_path do
        assert_select "button", text: "Sign out"
        assert_select "input[type=hidden][name=_method][value=delete]"
      end
    end
    assert_select "details.sm\\:hidden:not(.relative)[data-close-on-outside]", 1 do
      assert_select "summary.size-11:not(.w-48)[class*='focus-visible:']" do
        assert_select "svg[viewBox='0 0 24 24'] path[d='M4 6l16 0']"
        assert_select "span.sr-only", text: "Open navigation menu"
      end
      assert_select "div.absolute.inset-x-0.top-full.w-full.z-20:not(.mt-2):not(.w-56)" do
        assert_select "div.mx-auto.max-w-6xl.px-5" do
          assert_select "nav[aria-label='Mobile navigation']", 1
          assert_select "a", text: "Dashboard", count: 0
          assert_select "[data-theme-toggle]", 0
          assert_select "form[action=?][method=post]", session_path do
            assert_select "button", text: "Sign out"
            assert_select "input[type=hidden][name=_method][value=delete]"
          end
        end
      end
    end

    delete session_path

    assert_redirected_to new_session_path

    get root_path

    assert_response :success
    assert_select "header nav[aria-label='Main navigation'] a[href=?]", games_path, text: "Games"
    assert_select "header details.hidden.sm\\:block", count: 0
    assert_select "header details.sm\\:hidden", count: 1
    assert_select "header a[href=?]", new_session_path, text: "Sign In", count: 2
  end

  test "desktop account summary displays an attached avatar before the name" do
    user = users(:one)
    user.avatar.attach(fixture_file_upload("avatar.svg", "image/svg+xml"))
    sign_in_as user

    get root_path

    assert_response :success
    assert_select "details.hidden.sm\\:block > summary" do
      assert_select "img:first-child.size-6.shrink-0.rounded-full.object-cover[alt=''][src*='/rails/active_storage/blobs/']", count: 1
      assert_select "svg.size-6", count: 0
      assert_select "span.truncate", text: user.email_address
    end
    assert_select "details.sm\\:hidden > summary svg path[d='M4 6l16 0']", count: 1
  end

  test "signed-in mobile menu retains account actions below public navigation" do
    users(:one).update!(display_name: "Pat Example")
    sign_in_as users(:one)

    get root_path

    assert_response :success
    assert_select "details.sm\\:hidden" do
      assert_select "nav[aria-label='Mobile navigation'] > a" do |links|
        assert_equal %w[Picks Games Leaders Legends], links.map(&:text)
      end
      assert_select "nav + br + hr + br + div.flex.items-center", text: /Pat Example/
      assert_select "a[href=?]", profile_path, text: "My Profile"
      assert_select "a[href=?]", my_picks_path, text: "My Picks"
      assert_select "form[action=?] button", session_path, text: "Sign Out"
      assert_select "a[href=?]", new_session_path, count: 0
    end
    assert_select "details.hidden.sm\\:block > summary", text: /Pat Example/
    assert_select "header a[href=?]", new_session_path, count: 0
  end

  test "account menu uses full name or email when display name is absent" do
    user = users(:two)
    user.update!(first_name: "Sam", last_name: "Example")
    sign_in_as user

    get root_path
    assert_select "details.hidden.sm\\:block > summary", text: /Sam Example/

    user.update!(first_name: nil, last_name: nil)
    get root_path
    assert_select "details.hidden.sm\\:block > summary", text: /#{Regexp.escape(user.email_address)}/
  end

  test "long account names stay within the account menus" do
    user = users(:one)
    name = ("Very long account name " * 12).strip
    user.update!(display_name: name)
    sign_in_as user

    get root_path

    assert_select "header > div.flex-wrap > div.items-center.gap-2 > div.sm\\:flex.min-w-0.max-w-full" do
      assert_select "details.min-w-0.max-w-full > summary.h-11.w-40" do
        assert_select "span.min-w-0.flex-1.truncate[title=?]", name, text: name
      end
      assert_select "details > div.absolute.right-0.w-56[class~='max-w-[calc(100vw-2.5rem)]']"
    end
    assert_select "details.sm\\:hidden > div > div > div.flex.items-center.gap-2" do
      assert_select "> svg.size-6.shrink-0[aria-hidden=true]", count: 1
      assert_select "> span.min-w-0.flex-1.truncate[title=?]", name, text: name
    end
  end

  test "anonymous visitor sees the public dashboard and shared navigation" do
    game = dashboard_game("Visitor Bowl", start: 1.day.from_now)

    get root_path

    assert_response :success
    assert_select "h2#scoreboard-heading", text: "Scoreboard"
    assert_select "head link[rel=stylesheet][href*='lexxy']", count: 1
    assert_select "#game_#{game.id} h3", text: "Visitor Bowl"
    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']", 1 do |sources|
      assert_equal "dashboard_games", Turbo.signed_stream_verifier.verified(sources.first["signed-stream-name"])
    end
    assert_select "header a[href=?] > svg[data-icon=mouthguard][aria-hidden=true] + span", root_path, text: "Mouthguard", count: 1
    assert_select "header nav[aria-label='Main navigation'] > a" do |links|
      assert_equal %w[Games Picks Leaders Legends], links.map(&:text)
    end
    assert_select "header [data-theme-toggle]", count: 1
    assert_select "header > div.flex-wrap > div.items-center.gap-2 > div.sm\\:flex a.h-11.w-40[href=?]", new_session_path, text: "Sign In", count: 1
    assert_select "header details.hidden.sm\\:block", count: 0
    assert_select "header details.sm\\:hidden", count: 1 do
      assert_select "summary span.sr-only", text: "Open navigation menu"
      assert_select "nav[aria-label='Mobile navigation'] > a" do |links|
        assert_equal %w[Picks Games Leaders Legends], links.map(&:text)
      end
      assert_select "nav + br + hr + br + a[href=?]", new_session_path, text: "Sign In", count: 1
      assert_select "a[href=?]", profile_path, count: 0
      assert_select "a[href=?]", my_picks_path, count: 0
      assert_select "form[action=?]", session_path, count: 0
    end
  end

  test "cable session marker changes across sign in and sign out" do
    get root_path
    assert_select "body[data-cable-session='']"

    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    assert_response :redirect
    get root_path
    assert_select "body[data-cable-session=?]", users(:one).sessions.last.id.to_s

    delete session_path
    assert_response :redirect
    get root_path
    assert_select "body[data-cable-session='']"
  end

  test "mouthguard asset leaves size and color to the view" do
    assert_not File.exist?(Rails.root.join("app/assets/svg/icons/tabler/filled/mouthguard.svg"))
    asset = Nokogiri::XML(File.read(Rails.root.join("app/assets/svg/icons/custom/mouthguard.svg"))) { |config| config.strict }
    svg = asset.root

    assert_equal "0 0 24 24", svg["viewBox"]
    assert_equal "currentColor", svg["fill"]
    assert_nil svg["width"]
    assert_nil svg["height"]
    assert_nil svg["class"]
    assert_equal "M2 5a2 2 0 0 1 4 0v4a6 6 0 0 0 12 0V5a2 2 0 0 1 4 0v4A10 10 0 0 1 2 9V5Z", svg.at_xpath("./*[local-name()='path']")["d"]
    refute_match(/#[0-9a-fA-F]{3,8}\b|\b(?:white|black|amber)\b/, asset.to_xml)
  end

  test "anonymous sign in and password forms offer theme controls and dark inputs" do
    get new_session_path

    assert_response :success
    assert_select "body.bg-linear-to-b[class~='from-amber-50'][class~='to-[#f5efdf]'][class~='dark:from-neutral-900'][class~='dark:to-neutral-950']", 1
    assert_select "main.bg-linear-to-b", 0
    assert_select "header [data-theme-toggle][type=button][role=switch][aria-label='Dark Mode'][title='Toggle dark mode'][aria-checked=false]", 1
    assert_select "header [data-theme-system]", 0
    assert_select "body.bg-amber-50.dark\\:bg-neutral-950"
    assert_select "header.bg-black.bg-linear-to-b.from-neutral-800.to-black:not(.shadow-md):not([class~='shadow-black/25'])"
    assert_select "header.border-b", 0
    assert_select "header a[href=?] > svg[data-icon=mouthguard] + span", root_path, text: "Mouthguard"
    assert_select "header div.flex-wrap > div.items-center.gap-2" do
      assert_select "> [data-theme-toggle].size-11[class*='focus-visible:'][role=switch]", 1
      assert_select "[data-theme-icon=off][aria-hidden=true]:not([hidden]) path[d='M12 3c.132 0 .263 0 .393 0a7.5 7.5 0 0 0 7.92 12.446a9 9 0 1 1 -8.313 -12.454l0 .008']", 1
      assert_select "[data-theme-icon=on][aria-hidden=true][hidden] path[d='M8 12a4 4 0 1 0 8 0a4 4 0 1 0 -8 0']", 1
      assert_select "div.sm\\:flex a[href=?]", new_session_path, text: "Sign In"
    end
    assert_select "header [data-theme-toggle].bg-pine-400", 0
    assert_select "input[name='email_address'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[name='email_address'].border-pine-950.focus\\:outline-pine-950.dark\\:focus\\:outline-pine-400", 1
    assert_select "input[name='password'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[type=submit].bg-pine-900.dark\\:bg-pine-700.dark\\:text-neutral-100:not(.bg-linear-to-b):not(.shadow-sm)", 1

    get new_password_path
    assert_select "header.bg-black"
    assert_select "header [data-theme-toggle]", 1
    assert_select "input[name='email_address'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[type=submit].bg-pine-900.dark\\:bg-pine-700.dark\\:text-neutral-100:not(.bg-linear-to-b):not(.shadow-sm)", 1

    get edit_password_path(users(:one).password_reset_token)
    assert_select "header.bg-black"
    assert_select "header [data-theme-toggle]", 1
    assert_select "input[name='password'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[name='password_confirmation'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[type=submit].bg-pine-900.dark\\:bg-pine-700.dark\\:text-neutral-100:not(.bg-linear-to-b):not(.shadow-sm)", 1
  end

  private

  def dashboard_game(notes, **attributes)
    Game.create!({ cfbd_id: Game.maximum(:cfbd_id).to_i + 1, season: Current.season, notes: notes }.merge(attributes))
  end
end
