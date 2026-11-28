require "test_helper"

class ThreadsGameStripTest < ActionDispatch::IntegrationTest
  test "Threads links every current-season game and distinguishes live, upcoming, and final" do
    live = create_game("Live bowl", start: 1.hour.ago, period: "2", clock: "04:12")
    upcoming = create_game("Upcoming bowl", start: 1.day.from_now)
    unscheduled = create_game("TBD bowl")
    completed = create_game("Completed bowl", start: 1.day.ago, completed: true)
    status_completed = create_game("Status final bowl", start: 2.days.ago, status: "completed")
    other_season = create_game("Other season bowl", season: Current.season - 1)
    Comment.create!(user: users(:one), game: upcoming, body: "First")
    3.times { |i| Comment.create!(user: users(:one), game: completed, body: "Final #{i}") }
    old = Comment.create!(user: users(:one), game: completed, body: "Old")
    old.update_column(:season, Current.season - 1)
    Comment.create!(user: users(:one), body: "General")
    sign_in_as users(:one)

    get threads_path

    assert_response :success
    assert_select "main > h1", text: "Trash Talk"
    assert_select "section[aria-labelledby=threads-games-heading] > div.overflow-x-clip > div.overflow-x-auto" do
      assert_select "a[data-game-status]" do |cards|
        assert_equal [live, upcoming, unscheduled, status_completed, completed].map { |game| game_path(game) },
                     cards.map { |card| card["href"] }
        assert_equal %w[live upcoming upcoming final final], cards.map { |card| card["data-game-status"] }
      end
    end
    assert_select "section[aria-labelledby=threads-games-heading] a[href=?]", game_path(other_season), count: 0
    assert_select "a[href=?][data-game-status=live].bg-pine-100 span.font-bold.text-pine-700", game_path(live), text: "0 comments"
    assert_select "a[href=?][data-game-status=upcoming].bg-white span", game_path(upcoming), text: "1 comment"
    assert_select "a[href=?][data-game-status=upcoming] span", game_path(unscheduled), text: "0 comments"
    [completed, status_completed].each do |game|
      assert_select "a[href=?][data-game-status=final].opacity-60 span.font-bold.text-neutral-600",
        game_path(game), text: game == completed ? "3 comments" : "0 comments"
    end
  end

  test "Threads puts live and upcoming games before a slate of finals with stable kickoff order" do
    finals = 5.times.map { |i| create_game("Final #{i}", start: (5 - i).days.ago, completed: true) }
    upcoming = create_game("Upcoming", start: 2.hours.from_now)
    live = create_game("Live", start: 1.hour.ago)
    tied = create_game("Tied kickoff", start: upcoming.start)
    tbd = create_game("TBD")
    sign_in_as users(:one)

    get threads_path

    assert_select "[aria-label='Season games'] > a" do |cards|
      assert_equal [live, upcoming, tied, tbd, *finals].map { |game| game_path(game) },
                   cards.map { |card| card["href"] }
    end
  end

  test "Threads subscribes to game updates separately from general comments" do
    game = create_game("Live bowl", start: 1.hour.ago)
    sign_in_as users(:one)

    get threads_path

    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']", count: 2 do |sources|
      assert_equal %w[threads_games threads_comments],
                   sources.map { |source| Turbo.signed_stream_verifier.verified(source["signed-stream-name"]) }
    end
    assert_select "[aria-label='Season games'] > a#threads_game_#{game.id}[data-game-status=live][href=?]", game_path(game)
  end

  test "Threads game strip offers progressive carousel controls without replacing its scrollable region" do
    create_game("First bowl")
    create_game("Second bowl")
    sign_in_as users(:one)

    get threads_path

    assert_select "section[data-controller='threads-carousel'][aria-labelledby='threads-games-heading']" do
      assert_select "h2#threads-games-heading", count: 0
      assert_select "div.overflow-x-clip > div[data-threads-carousel-target='track'][role='region'][aria-label='Season games'][tabindex='0'].overflow-x-auto.threads-games-track.px-12.scroll-px-12 > a", count: 2
      assert_select "div.overflow-x-clip > div[aria-hidden='true'].pointer-events-none.absolute.inset-y-0.left-0.w-12.bg-linear-to-r.from-amber-50.to-transparent.dark\\:from-neutral-900", count: 1
      assert_select "div.overflow-x-clip > div[aria-hidden='true'].pointer-events-none.absolute.inset-y-0.right-0.w-12.bg-linear-to-l.from-amber-50.to-transparent.dark\\:from-neutral-900", count: 1
      assert_select "button.hidden[aria-label='Previous game'][data-threads-carousel-target='previous'][data-action='threads-carousel#previous']", 1
      assert_select "button.hidden[aria-label='Next game'][data-threads-carousel-target='next'][data-action='threads-carousel#next']", 1
    end
    styles = Rails.root.join("app/assets/stylesheets/application.css").read
    assert_match(/\.threads-games-track\s*\{[^}]*scrollbar-width:\s*none;/m, styles)
    assert_match(/\.threads-games-track::-webkit-scrollbar\s*\{[^}]*display:\s*none;/m, styles)
  end

  private

  def create_game(notes, **attributes)
    Game.create!({ cfbd_id: Game.maximum(:cfbd_id).to_i + 1, notes: notes, season: Current.season }.merge(attributes))
  end
end
