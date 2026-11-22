require "test_helper"

class PicksTest < ActionDispatch::IntegrationTest
  test "generic Picks remains separate from the account's My Picks page" do
    sign_in_as users(:one)

    assert_no_difference "users(:one).picks.count" do
      get picks_path
    end

    assert_response :success
    assert_select "main h1", text: "Picks"
    assert_select "main article", count: 0
    assert_select "nav[aria-label='Main navigation'] a[href=?]", picks_path, text: "Picks"
    assert_select "nav[aria-label='Mobile navigation'] a[href=?]", picks_path, text: "Picks"
    assert_select "details.hidden.sm\\:block a[href=?]", my_picks_path, text: "My Picks", count: 1
    assert_select "details.sm\\:hidden a[href=?]", my_picks_path, text: "My Picks", count: 1
    assert_select "nav a[href=?]", my_picks_path, count: 0
  end
end
