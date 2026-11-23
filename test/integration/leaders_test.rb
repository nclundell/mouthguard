require "test_helper"

class LeadersTest < ActionDispatch::IntegrationTest
  test "leaderboard renders ranks, scores, statuses and avatar fallback" do
    winner, eliminated = users(:one), users(:two)
    winner.update!(display_name: "Winner")
    eliminated.update!(display_name: "Eliminated user")
    winner.avatar.attach(fixture_file_upload("avatar.svg", "image/svg+xml"))
    match = Game.create!(cfbd_id: 99_001, season: Current.season, start: 1.day.ago)
    Pick.create!(user: winner, game: match, correct: true)
    sign_in_as winner

    get leaders_path

    assert_response :success
    assert_select "main h1", text: "#{Current.season} Leader Board"
    assert_select "main section[aria-label=Leaderboard] article", count: 2 do |cards|
      assert_equal [ "Winner", "Eliminated user" ], cards.map { |card| card.at_css("h2").text.strip }
      assert_equal [ "Rank 1", "Rank 2" ], cards.map { |card| card.at_css("[aria-label^='Rank']")["aria-label"] }
      assert_equal [ "1 point", "0 points" ], cards.map { |card| card.at_css("[aria-label$='point'], [aria-label$='points']")["aria-label"] }
      assert_equal [ "Can win", "Eliminated" ], cards.map { |card| card.at_css("span.block.text-xs").text.strip }
    end
    assert_select "main article:first-of-type img[alt='Avatar for Winner']", 1
    assert_select "main article:nth-of-type(2) svg[aria-hidden=true]", 1
    assert_select "main article:first-of-type svg[data-icon=crown][aria-hidden=true]", 1
    assert_select "main article:first-of-type svg[data-icon=crown].absolute.-top-2.-left-1.z-10.size-5.-rotate-20.text-amber-500", 1
    assert_select "main article:nth-of-type(2) svg[data-icon=crown]", 0
    assert_select "main article:first-of-type .bg-green-100.dark\\:bg-green-900", 1
    assert_select "main article:nth-of-type(2) .bg-red-100.dark\\:bg-red-900", 1
  end

  test "tied leaders have no crown" do
    first, second = users(:one), users(:two)
    Pick.create!(user: first, game: Game.create!(cfbd_id: 99_002, season: Current.season, start: 1.day.ago), correct: true)
    Pick.create!(user: second, game: Game.create!(cfbd_id: 99_003, season: Current.season, start: 1.day.ago), correct: true)
    sign_in_as first

    get leaders_path

    assert_response :success
    assert_select "main article [aria-label='Rank 1']", count: 2
    assert_select "main article svg[data-icon=crown]", count: 0
  end

  test "no crown when a lower-ranked user can still win" do
    first, second = users(:one), users(:two)
    2.times do |index|
      game = Game.create!(cfbd_id: 99_010 + index, season: Current.season, start: 1.day.ago)
      Pick.create!(user: first, game: game, correct: true)
    end
    team = Team.create!(cfbd_id: 99_020)
    3.times do |index|
      game = Game.create!(cfbd_id: 99_030 + index, season: Current.season, start: 1.day.from_now, home: team)
      Pick.create!(user: second, game: game, team: team)
    end
    sign_in_as first

    get leaders_path

    assert_response :success
    assert_select "main article [aria-label='Rank 1']", count: 1
    assert_select "main article [aria-label='Rank 2']", count: 1
    assert_select "main article .bg-green-100.dark\\:bg-green-900", count: 2
    assert_select "main article svg[data-icon=crown]", count: 0
  end

  test "leaderboard shows empty state without users" do
    html = ApplicationController.render(template: "leaders/index", layout: false,
                                        assigns: { season: Current.season, leaders: [] })

    assert_includes html, "No leaders yet."
    assert_not_includes html, "<article"
    assert_not_includes html, "data-icon=\"crown\""
  end

  test "leaderboard with no eligible contenders has no crown" do
    rows = [ users(:one), users(:two) ].each_with_index.map do |user, index|
      UserRankingService::Row.new(user: user, name: "Player", points: 0, rank: index + 1, can_win: false)
    end
    html = ApplicationController.render(template: "leaders/index", layout: false,
                                        assigns: { season: Current.season, leaders: rows })

    assert_equal 2, Nokogiri::HTML(html).css("article").size
    assert_empty Nokogiri::HTML(html).css("svg[data-icon=crown]")
  end

  test "email-only leader shows a fallback name without revealing email" do
    winner = users(:one)
    winner.update!(display_name: "Winner")
    email_only = User.create!(email_address: "private@example.com", password: "password")
    email_only.avatar.attach(fixture_file_upload("avatar.svg", "image/svg+xml"))
    sign_in_as winner

    get leaders_path

    assert_response :success
    assert_select "main article h2", text: "Player", count: 2
    assert_select "main article img[alt='Avatar for Player']", count: 1
    assert_no_match(/private@example\.com/, response.body)
  end
end
