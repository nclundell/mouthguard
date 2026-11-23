require "test_helper"

class UserRankingServiceTest < ActiveSupport::TestCase
  def game(season: Current.season, start: 1.day.from_now)
    Game.create!(cfbd_id: SecureRandom.random_number(1_000_000_000), season: season, start: start)
  end

  def pick(user, game, team_id: nil, correct: nil)
    Pick.create!(user: user, game: game, team_id: team_id, correct: correct)
  end

  test "sorts scores with competition ranks and includes users without picks" do
    alice, bob = users(:one), users(:two)
    alice.update!(display_name: "alice")
    bob.update!(display_name: "Bob")
    charlie = User.create!(email_address: "charlie@example.com", password: "password", display_name: "Charlie")
    first = game(start: 1.day.ago)
    second = game(start: 1.day.ago)
    pick(alice, first, correct: true)
    pick(bob, second, correct: true)
    pick(charlie, game(season: Current.season - 1, start: 1.day.ago), correct: true)

    rows = UserRankingService.rank_users
    assert_equal [alice, bob, charlie], rows.map(&:user)
    assert_equal [1, 1, 3], rows.map(&:rank)
    assert_equal [1, 1, 0], rows.map(&:points)
    assert_equal [true, true, false], rows.map(&:can_win)
  end

  test "only selected differing picks in open current games give a chance to pass the leader" do
    leader, challenger = users(:one), users(:two)
    leader.update!(display_name: "Leader")
    challenger.update!(display_name: "Challenger")
    played = game(start: 1.day.ago)
    pick(leader, played, correct: true)
    pick(challenger, played, correct: false)
    home = Team.create!(cfbd_id: 91_001)
    away = Team.create!(cfbd_id: 91_002)
    future = game(start: nil)
    past = game(start: 1.day.ago)
    old = game(season: Current.season - 1)
    [future, past, old].each { |match| match.update_columns(home_id: home.id, away_id: away.id) }
    # A missing leader pick is safe and a selected challenger pick can still earn a point.
    pick(challenger, future, team_id: home.id)
    pick(challenger, past, team_id: home.id)
    pick(challenger, old, team_id: home.id)
    unselected = game(start: nil)
    unselected.update_columns(home_id: home.id, away_id: away.id)
    pick(challenger, unselected)

    assert_equal false, UserRankingService.rank_users.last.can_win # equal points cannot win

    second = game
    second.update_columns(home_id: home.id, away_id: away.id)
    pick(leader, second, team_id: home.id)
    pick(challenger, second, team_id: away.id)
    assert_equal true, UserRankingService.rank_users.last.can_win

    pick(leader, future, team_id: home.id)
    assert_equal false, UserRankingService.rank_users.last.can_win
    assert_equal true, UserRankingService.rank_users.first.can_win
  end

  test "completed games without a kickoff or with a future kickoff do not offer points" do
    leader, challenger = users(:one), users(:two)
    leader.update!(display_name: "Leader")
    challenger.update!(display_name: "Challenger")
    scored = game(start: 1.day.ago)
    pick(leader, scored, correct: true)
    home = Team.create!(cfbd_id: 91_003)

    [ game(start: nil), game(start: 1.day.from_now) ].each_with_index do |match, index|
      match.update_columns(home_id: home.id, completed: index.zero?, status: index.zero? ? nil : "completed")
      pick(challenger, match, team_id: home.id)
    end

    open_game = game
    open_game.update_columns(home_id: home.id)
    pick(challenger, open_game, team_id: home.id)

    assert_equal false, UserRankingService.rank_users.last.can_win
  end

  test "email-only users have a nonblank display name and sort deterministically" do
    alice = users(:one)
    alice.update!(display_name: "Alice")
    email_only = User.create!(email_address: "private@example.com", password: "password")

    rows = UserRankingService.rank_users

    assert_equal [ alice, users(:two), email_only ], rows.map(&:user)
    assert_equal [ "Alice", "Player", "Player" ], rows.map(&:name)
  end
end
