require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  test "authenticated user sees dashboard navigation and can sign out" do
    sign_in_as users(:one)

    get root_path

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_select "header a[href=?]", root_path, text: "Mouthguard"
    assert_select "nav[aria-label='Main navigation'].hidden.sm\\:block a[href=?]", root_path, text: "Dashboard"
    assert_select "form.hidden.sm\\:block[action=?][method=post]", session_path do
      assert_select "button", text: "Sign out"
      assert_select "input[type=hidden][name=_method][value=delete]"
    end
    assert_select "details.sm\\:hidden" do
      assert_select "summary.min-h-11[class*='focus-visible:']" do
        assert_select "svg[viewBox='0 0 24 24'] path[d='M4 6l16 0']"
        assert_select "span.sr-only", text: "Open navigation menu"
      end
      assert_select "nav[aria-label='Mobile navigation'] a[href=?]", root_path, text: "Dashboard"
      assert_select "form[action=?][method=post]", session_path do
        assert_select "button", text: "Sign out"
        assert_select "input[type=hidden][name=_method][value=delete]"
      end
    end

    delete session_path

    assert_redirected_to new_session_path

    get root_path

    assert_redirected_to new_session_path
  end

  test "anonymous visitor is redirected to sign in" do
    get root_path

    assert_redirected_to new_session_path
  end
end
