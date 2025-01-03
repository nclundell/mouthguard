require "application_system_test_case"

class GamesTest < ApplicationSystemTestCase
  setup do
    @game = games(:one)
  end

  # test "visiting the index" do
  #   visit games_url
  #   assert_selector "h1", text: "Games"
  # end
  #
  # test "should create game" do
  #   visit games_url
  #   click_on "New game"
  #
  #   fill_in "Attendance", with: @game.attendance
  #   fill_in "Away id", with: @game.away_id_id
  #   fill_in "Away line scores", with: @game.away_line_scores
  #   fill_in "Away points", with: @game.away_points
  #   fill_in "Cfbd", with: @game.cfbd_id
  #   check "Completed" if @game.completed
  #   fill_in "Highlights", with: @game.highlights
  #   fill_in "Home id", with: @game.home_id_id
  #   fill_in "Home line scores", with: @game.home_line_scores
  #   fill_in "Home points", with: @game.home_points
  #   fill_in "Notes", with: @game.notes
  #   fill_in "Season", with: @game.season
  #   fill_in "Start", with: @game.start
  #   fill_in "Venue id", with: @game.venue_id_id
  #   click_on "Create Game"
  #
  #   assert_text "Game was successfully created"
  #   click_on "Back"
  # end
  #
  # test "should update Game" do
  #   visit game_url(@game)
  #   click_on "Edit this game", match: :first
  #
  #   fill_in "Attendance", with: @game.attendance
  #   fill_in "Away id", with: @game.away_id_id
  #   fill_in "Away line scores", with: @game.away_line_scores
  #   fill_in "Away points", with: @game.away_points
  #   fill_in "Cfbd", with: @game.cfbd_id
  #   check "Completed" if @game.completed
  #   fill_in "Highlights", with: @game.highlights
  #   fill_in "Home id", with: @game.home_id_id
  #   fill_in "Home line scores", with: @game.home_line_scores
  #   fill_in "Home points", with: @game.home_points
  #   fill_in "Notes", with: @game.notes
  #   fill_in "Season", with: @game.season
  #   fill_in "Start", with: @game.start.to_s
  #   fill_in "Venue id", with: @game.venue_id_id
  #   click_on "Update Game"
  #
  #   assert_text "Game was successfully updated"
  #   click_on "Back"
  # end
  #
  # test "should destroy Game" do
  #   visit game_url(@game)
  #   click_on "Destroy this game", match: :first
  #
  #   assert_text "Game was successfully destroyed"
  # end
end
