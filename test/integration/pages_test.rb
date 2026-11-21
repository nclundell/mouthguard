require "test_helper"

class PagesTest < ActionDispatch::IntegrationTest
  test "authenticated pages show their headings and navigation links" do
    sign_in_as users(:one)

    { picks: "Picks", games: "Games", leaders: "Leaders", legends: "Legends" }.each do |page, title|
      get public_send("#{page}_path")

      assert_response :success
      assert_select "main > h1.border-pine-950.dark\\:border-pine-500", text: title, count: 1
      assert_select "nav[aria-label='Main navigation'].hidden.sm\\:flex a[href=?]", public_send("#{page}_path"), text: title, count: 1
      assert_select "nav[aria-label='Mobile navigation'] a[href=?]", public_send("#{page}_path"), text: title, count: 1
    end
  end

  test "anonymous visitors are redirected to sign in from every page" do
    %w[/picks /games /leaders /legends].each do |path|
      get path

      assert_redirected_to new_session_path
    end
  end
end
