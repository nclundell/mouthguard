require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  test "authenticated user sees dashboard navigation and can sign out" do
    sign_in_as users(:one)

    get root_path

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_select "body.bg-linear-to-b[class~='from-amber-50'][class~='to-[#f5efdf]'][class~='dark:from-neutral-900'][class~='dark:to-neutral-950']", 1
    assert_select "main.bg-linear-to-b", 0
    assert_select "body.dark\\:bg-neutral-950.dark\\:text-neutral-100"
    assert_select "h1.dark\\:text-neutral-100", text: "Dashboard"
    assert_select "header.relative.bg-black.bg-linear-to-b.from-neutral-800.to-black:not(.shadow-md):not([class~='shadow-black/25'])"
    assert_select "header.border-b", 0
    assert_select "details > div.bg-black:not(.border):not(.border-neutral-800):not(.bg-linear-to-b):not(.from-neutral-900):not(.to-black):not(.shadow-lg)"
    assert_select "header a.text-brass-300", text: "Mouthguard"
    assert_select "h1.border-brass-700.dark\\:border-brass-300", text: "Dashboard"
    assert_select "head script[src*='theme']", 1
    assert_select "header [data-theme-toggle][type=button][aria-label='Switch to dark mode']", 2
    assert_select "header [data-theme-system][hidden]", 2
    assert_select "header a[href=?]", root_path, text: "Mouthguard"
    assert_select "nav[aria-label='Main navigation'].hidden.sm\\:block a[href=?]", root_path, text: "Dashboard"
    assert_select "form.hidden.sm\\:block[action=?][method=post]", session_path do
      assert_select "button", text: "Sign out"
      assert_select "input[type=hidden][name=_method][value=delete]"
    end
    assert_select "details.sm\\:hidden:not(.relative)" do
      assert_select "summary.min-h-11[class*='focus-visible:']" do
        assert_select "svg[viewBox='0 0 24 24'] path[d='M4 6l16 0']"
        assert_select "span.sr-only", text: "Open navigation menu"
      end
      assert_select "div.absolute.inset-x-0.top-full.w-full.z-20:not(.mt-2):not(.w-56)" do
        assert_select "div.mx-auto.max-w-6xl.px-5" do
          assert_select "nav[aria-label='Mobile navigation'] a[href=?]", root_path, text: "Dashboard"
          assert_select "form[action=?][method=post]", session_path do
            assert_select "button", text: "Sign out"
            assert_select "input[type=hidden][name=_method][value=delete]"
          end
        end
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

  test "anonymous sign in and password forms offer theme controls and dark inputs" do
    get new_session_path

    assert_response :success
    assert_select "body.bg-linear-to-b[class~='from-amber-50'][class~='to-[#f5efdf]'][class~='dark:from-neutral-900'][class~='dark:to-neutral-950']", 1
    assert_select "main.bg-linear-to-b", 0
    assert_select "header [data-theme-toggle][type=button]", 1
    assert_select "header [data-theme-system][hidden]", 1
    assert_select "body.bg-amber-50.dark\\:bg-neutral-950"
    assert_select "header.bg-black.bg-linear-to-b.from-neutral-800.to-black:not(.shadow-md):not([class~='shadow-black/25'])"
    assert_select "header.border-b", 0
    assert_select "header span.text-brass-300", text: "Mouthguard"
    assert_select "header [data-theme-toggle].bg-brass-300.text-neutral-950:not(.bg-linear-to-b):not(.shadow-sm)"
    assert_select "input[name='email_address'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[name='email_address'].border-brass-700.focus\\:outline-brass-700.dark\\:focus\\:outline-brass-300", 1
    assert_select "input[name='password'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[type=submit].bg-brass-700.dark\\:bg-brass-300.dark\\:text-neutral-950:not(.bg-linear-to-b):not(.shadow-sm)", 1

    get new_password_path
    assert_select "header.bg-black"
    assert_select "header [data-theme-toggle]", 1
    assert_select "input[name='email_address'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[type=submit].bg-brass-700.dark\\:bg-brass-300.dark\\:text-neutral-950:not(.bg-linear-to-b):not(.shadow-sm)", 1

    get edit_password_path(users(:one).password_reset_token)
    assert_select "header.bg-black"
    assert_select "header [data-theme-toggle]", 1
    assert_select "input[name='password'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[name='password_confirmation'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[type=submit].bg-brass-700.dark\\:bg-brass-300.dark\\:text-neutral-950:not(.bg-linear-to-b):not(.shadow-sm)", 1
  end
end
