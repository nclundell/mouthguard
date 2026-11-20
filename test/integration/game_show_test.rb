require "test_helper"

class GameShowTest < ActionDispatch::IntegrationTest
  test "authenticated visitor sees the game page" do
    game = Game.create!(cfbd_id: Game.maximum(:cfbd_id).to_i + 1)
    sign_in_as users(:one)

    get game_path(game)

    assert_response :success
    assert_select "main > h1.border-green-800.dark\\:border-green-300", text: "Game", count: 1
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
