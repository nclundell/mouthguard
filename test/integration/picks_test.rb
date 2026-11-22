require "test_helper"

class PicksTest < ActionDispatch::IntegrationTest
  setup do
    @away = Team.create!(cfbd_id: Team.maximum(:cfbd_id).to_i + 1, school: "Away School")
    @home = Team.create!(cfbd_id: @away.cfbd_id + 1, school: "Home School")
    @locked = create_game(notes: "Locked Bowl", start: 1.hour.ago)
    @future = create_game(notes: "Future Bowl", start: 1.day.from_now)
    @unknown = create_game(notes: "Unknown Bowl", start: nil)
    users(:one).update!(display_name: "First Fan")
    sign_in_as users(:one)
  end

  test "renders season games and locked picks for the grid and mobile without changing picks" do
    @locked.update!(tv: "ESPN")
    users(:two).update!(display_name: "Second Fan")
    Pick.create!(game: @locked, user: users(:one), team: @away)
    Pick.create!(game: @locked, user: users(:two), team: @home)
    other = create_game(notes: "Other Bowl", start: 2.hours.ago, home: nil)
    old = create_game(notes: "Old Bowl", start: 1.hour.ago, season: Current.season - 1)
    Pick.create!(game: old, user: users(:two), team: @home)

    assert_no_difference "Pick.count" do
      get picks_path
    end

    assert_response :success
    assert_select "link[rel=stylesheet][href*='application-']", count: 1
    assert_select "link[rel=stylesheet][href*='tabulator-']", count: 0
    assert_select "[data-controller='picks-heading']", count: 0
    assert_select "div[data-controller='picks-sticky-header'] div[role=region][tabindex='0'][class~='overflow-x-auto'][class~='max-w-full']", count: 1
    assert_select "div[role=region][class*='max-h-']", count: 0
    assert_select "div[role=region][data-picks-sticky-header-target='scroller']", count: 1
    assert_select "div[role=region] table[data-picks-sticky-header-target='table']", count: 1
    assert_select "main thead", count: 1
    assert_select "div[role=region] table" do
      assert_select "thead[data-picks-sticky-header-target='header']", count: 1
      assert_select "thead[aria-hidden]", count: 0
      assert_select "thead th", text: "Game", count: 1
      assert_select "thead th[class~='sticky'][class~='left-0']", text: "Game", count: 1
      assert_select "thead th[class~='top-0']", count: 0
      assert_select "thead th", text: "First Fan", count: 1
      assert_select "thead th", text: "Second Fan", count: 1
      assert_select "thead th[class~='sticky']", count: 1
      assert_select "tbody tr", count: 4
      assert_select "tbody th[class~='sticky'][class~='left-0']", count: 4
      assert_select "tbody td[class~='sticky']", count: 0
      assert_select "tr#game_#{@locked.id} th[scope=row]" do
        assert_select "span", text: "Away School vs Home School"
        assert_select "time[datetime=?][data-controller='local-time']", @locked.start.iso8601,
                      text: @locked.start.strftime("%b %-d, %Y at %-I:%M %p")
        assert_select "span", text: "ESPN", count: 1
      end
      assert_select "tr#game_#{@unknown.id} th[scope=row]" do
        assert_select "time", count: 0
        assert_select "span", text: "Kickoff TBD", count: 1
      end
      assert_select "tr#game_#{@locked.id} td", text: "Away School", count: 1
      assert_select "tr#game_#{@locked.id} td", text: "Home School", count: 1
      assert_select "tr#game_#{other.id} th", text: /TBD/
      assert_select "tr#game_#{other.id} td", text: "No pick", count: 2
      assert_select "tr#game_#{@future.id} td", text: "Picks hidden until kickoff"
      assert_select "tr#game_#{@unknown.id} td", text: "Picks hidden until kickoff"
    end
    assert_select "section#mobile_game_#{@locked.id} [data-picks-filter-target='userEntry']", count: 2
    assert_select "section#mobile_game_#{@future.id} [data-picks-filter-target='userEntry']", count: 0
    assert_select "section#mobile_game_#{@unknown.id} [data-picks-filter-target='userEntry']", count: 0
    assert_select "main", text: /Old Bowl/, count: 0
    assert_no_match(/one@example.com|two@example.com/, response.body)
  end

  test "searchable dropdowns start closed and unchecked while showing every bowl and user" do
    users(:two).update!(display_name: "Second Fan")
    Pick.create!(game: @locked, user: users(:one), team: @away)
    Pick.create!(game: @locked, user: users(:two), team: @home)

    get picks_path
    assert_select "[data-controller='picks-filter'] [data-picks-filter-target='controls'][class~='hidden'][class~='sm:flex']", count: 1 do
      assert_select "#bowl-search", count: 1
      assert_select "#user-search", count: 1
      assert_select "#bowl-options", count: 1
      assert_select "#user-options", count: 1
      assert_select "[data-picks-filter-target='gameRow']", count: 0
      assert_select "[data-picks-filter-target='gameCard']", count: 0
    end
    assert_select "label[for=bowl-search]", text: "Bowl", count: 1
    assert_select "label[for=user-search]", text: "User", count: 1
    assert_select "input#bowl-search[type=search][placeholder='Search bowls'][aria-label='Search bowls'][aria-controls=bowl-options][aria-expanded=false][class~='w-40'][class~='max-w-full'][data-action*='input->picks-filter#search']", count: 1
    assert_select "input#user-search[type=search][placeholder='Search users'][aria-label='Search users'][aria-controls=user-options][aria-expanded=false][class~='w-40'][class~='max-w-full'][data-action*='input->picks-filter#search']", count: 1
    assert_select "button[type=button][aria-label='Clear bowl filter'][title='Clear bowl filter'][data-picks-filter-target=bowlClear][data-action='click->picks-filter#clear'][disabled][hidden].hidden", count: 1 do
      assert_select "svg[aria-hidden=true]", count: 1
    end
    assert_select "button[type=button][aria-label='Clear user filter'][title='Clear user filter'][data-picks-filter-target=userClear][data-action='click->picks-filter#clear'][disabled][hidden].hidden", count: 1 do
      assert_select "svg[aria-hidden=true]", count: 1
    end
    assert_select "button[aria-label^='Clear'][data-action='click->picks-filter#clear']", text: "Clear", count: 0
    assert_select "#bowl-options[hidden][data-picks-filter-target=bowlDropdown]", count: 1
    assert_select "#user-options[hidden][data-picks-filter-target=userDropdown]", count: 1
    assert_select "[data-picks-filter-target='bowlCount']", text: "All"
    assert_select "[data-picks-filter-target='userCount']", text: "All"
    assert_select "[data-picks-filter-target='bowlOption'][hidden] input[type=checkbox][data-action='change->picks-filter#update']", count: 3
    assert_select "[data-picks-filter-target='userOption'][hidden] input[type=checkbox][data-action='change->picks-filter#update']", count: 2
    assert_select "[data-picks-filter-target='bowlOption'] input[checked]", count: 0
    assert_select "[data-picks-filter-target='userOption'] input[checked]", count: 0
    assert_select "[data-picks-filter-target='bowlOption']", text: "Locked Bowl", count: 1
    assert_select "[data-picks-filter-target='bowlOption']", text: "Future Bowl", count: 1
    assert_select "[data-picks-filter-target='bowlOption']", text: "Unknown Bowl", count: 1
    assert_select "[data-picks-filter-target='userOption']", text: /First Fan/, count: 1
    assert_select "[data-picks-filter-target='userOption']", text: /Second Fan/, count: 1
    assert_select "tr[data-picks-filter-target='gameRow'][data-game-id='#{@locked.id}']", count: 1
    assert_select "section[data-picks-filter-target='gameCard'][data-game-id='#{@locked.id}']", count: 1
    assert_select "th[data-picks-filter-target='userColumn'][data-user-id='#{users(:two).id}']", count: 1
    assert_select "td[data-picks-filter-target='userCell'][data-user-id='#{users(:two).id}']", count: 1
    assert_select "[data-picks-filter-target='userEntry'][data-user-id='#{users(:two).id}']", count: 1
    assert_select "[data-picks-filter-target='noGames'].hidden", text: "No games available", count: 1
    assert_select "tr#game_#{@future.id} td[data-picks-filter-target='lockedCell'][colspan='2']", count: 1
    assert_select "form[method=get]", count: 0

    get picks_path, params: { selected_user_ids: [ "", users(:two).id.to_s, "999999" ] }
    assert_select "[data-picks-filter-target='userCount']", text: "1 selected"
    assert_select "button[aria-label='Clear user filter']:not([disabled])", count: 1
    assert_select "button[aria-label='Clear user filter']:not([hidden]):not(.hidden)", count: 1
    assert_select "button[aria-label='Clear bowl filter'][disabled][hidden].hidden", count: 1
    assert_select "[data-picks-filter-target='userOption'] input[type=checkbox][checked]", count: 1
    assert_select "thead th.hidden", text: "First Fan", count: 1
    assert_select "thead th", text: "Second Fan", count: 1
    assert_select "tr#game_#{@locked.id} td[data-user-id='#{users(:one).id}'].hidden", count: 1
    assert_select "section#mobile_game_#{@locked.id} [data-user-id='#{users(:one).id}'].hidden", count: 1

    get picks_path, params: { selected_user_ids: [ "" ] }
    assert_select "[data-picks-filter-target='userOption'] input[checked]", count: 0
    assert_select "thead th", text: "First Fan"
    assert_select "thead th", text: "Second Fan"
    assert_select "thead th.hidden", text: "Selections", count: 1
    assert_select "tr#game_#{@locked.id} td[data-picks-filter-target='userCell']:not(.hidden)", count: 2
    assert_select "section#mobile_game_#{@locked.id} [data-picks-filter-target='userEntry']:not(.hidden)", count: 2
    assert_select "tr#game_#{@future.id} td[colspan='2']", text: "Picks hidden until kickoff"
  end

  test "duplicate bowl titles and unnamed games share one filter option across desktop and mobile" do
    other = create_game(notes: "Locked Bowl", start: 2.hours.ago)
    unnamed = create_game(notes: nil, start: 3.hours.ago)
    another_unnamed = create_game(notes: "", start: 4.hours.ago)
    create_game(notes: "Old Bowl", start: 5.hours.ago, season: Current.season - 1)

    get picks_path

    assert_select "[data-picks-filter-target='bowlOption']", count: 4
    assert_select "[data-picks-filter-target='bowlOption']", text: "Locked Bowl", count: 1
    assert_select "[data-picks-filter-target='bowlOption'] input[value='Locked Bowl']:not([checked])", count: 1
    assert_select "[data-picks-filter-target='bowlOption']", text: "Game", count: 1
    assert_select "[data-picks-filter-target='bowlOption'] input[value='Game']:not([checked])", count: 1
    [ @locked, other, unnamed, another_unnamed ].each do |game|
      title = game.notes.presence || "Game"
      assert_select "tr#game_#{game.id}[data-bowl-title='#{title}']", count: 1
      assert_select "section#mobile_game_#{game.id}[data-bowl-title='#{title}']", count: 1
    end
  end

  test "keeps persisted result indicators and never reveals picks before kickoff" do
    @locked.update!(completed: true, away_points: 21, home_points: 14)
    pick = Pick.create!(game: @locked, user: users(:one), team: @away)
    pick.update_column(:correct, false)
    secret = Team.create!(cfbd_id: @home.cfbd_id + 1, school: "Secret Selection")
    @future.update!(away: secret)
    @unknown.update!(away: secret)
    Pick.create!(game: @future, user: users(:one), team: secret)
    Pick.create!(game: @unknown, user: users(:one), team: secret)

    get picks_path

    assert_select "tr#game_#{@locked.id} span[role=img][aria-label='Incorrect pick']", count: 1
    assert_select "section#mobile_game_#{@locked.id} span[role=img][aria-label='Incorrect pick']", count: 1
    assert_select "main td", text: /Secret Selection/, count: 0
    assert_select "main [data-picks-filter-target='userEntry']", text: /Secret Selection/, count: 0
  end

  test "requires sign in" do
    sign_out
    get picks_path
    assert_redirected_to new_session_path
  end

  private

  def create_game(notes:, start:, season: Current.season, home: @home)
    Game.create!(cfbd_id: Game.maximum(:cfbd_id).to_i + 1, season: season,
                 away: @away, home: home, notes: notes, start: start)
  end
end
