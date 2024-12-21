require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game = games(:one)
  end

  test "should get index" do
    get games_url
    assert_response :success
  end

  test "should get new" do
    get new_game_url
    assert_response :success
  end

  test "should create game" do
    assert_difference("Game.count") do
      post games_url, params: { game: { attendance: @game.attendance, away_id_id: @game.away_id_id, away_line_scores: @game.away_line_scores, away_points: @game.away_points, cfbd_id: @game.cfbd_id, completed: @game.completed, highlights: @game.highlights, home_id_id: @game.home_id_id, home_line_scores: @game.home_line_scores, home_points: @game.home_points, notes: @game.notes, season: @game.season, start: @game.start, venue_id_id: @game.venue_id_id } }
    end

    assert_redirected_to game_url(Game.last)
  end

  test "should show game" do
    get game_url(@game)
    assert_response :success
  end

  test "should get edit" do
    get edit_game_url(@game)
    assert_response :success
  end

  test "should update game" do
    patch game_url(@game), params: { game: { attendance: @game.attendance, away_id_id: @game.away_id_id, away_line_scores: @game.away_line_scores, away_points: @game.away_points, cfbd_id: @game.cfbd_id, completed: @game.completed, highlights: @game.highlights, home_id_id: @game.home_id_id, home_line_scores: @game.home_line_scores, home_points: @game.home_points, notes: @game.notes, season: @game.season, start: @game.start, venue_id_id: @game.venue_id_id } }
    assert_redirected_to game_url(@game)
  end

  test "should destroy game" do
    assert_difference("Game.count", -1) do
      delete game_url(@game)
    end

    assert_redirected_to games_url
  end
end
