require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  test "authenticated user sees brand navigation and can sign out" do
    users(:one).update!(display_name: "Pat Example")
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
    assert_select "header a.text-green-300", text: "Mouthguard"
    assert_select "h1.border-green-800.dark\\:border-green-300", text: "Dashboard"
    assert_select "head script[src*='theme']", 1
    assert_select "header [data-theme-toggle][type=button][role=switch][aria-label='Dark Mode'][aria-checked=false]", text: "Dark Mode", count: 2
    assert_select "header [data-theme-toggle].w-full.justify-between.min-h-11.px-3:not(.bg-green-300)", 2
    assert_select "header [data-theme-toggle][class*='focus-visible:']", 2
    assert_select "header [data-theme-toggle] > span:first-child", text: "Dark Mode", count: 2
    assert_select "header [data-theme-toggle] > svg[data-theme-icon=off].text-green-300[aria-hidden=true] path[d='M6 12a2 2 0 1 0 4 0a2 2 0 1 0 -4 0']", 2
    assert_select "header [data-theme-toggle] > svg[data-theme-icon=on].text-green-300[aria-hidden=true][hidden] path[d='M14 12a2 2 0 1 0 4 0a2 2 0 1 0 -4 0']", 2
    assert_select "header [data-theme-system]", 0
    assert_select "header a[href=?]", root_path, text: "Mouthguard"
    assert_select "header nav[aria-label='Main navigation']", 1
    assert_select "header a", text: "Dashboard", count: 0
    assert_select "details.hidden.sm\\:block[data-close-on-outside]", 1 do
      assert_select "summary[class*='focus-visible:']", text: /Pat Example/
      assert_select "summary svg[aria-hidden='true'] path[d='M6 9l6 6l6 -6']"
      assert_select "div p", text: users(:one).email_address
      assert_select "div.absolute.w-56 > [data-theme-toggle].w-full.justify-between[role=switch]", text: "Dark Mode", count: 1
      assert_select "div.absolute.w-56 > form > button.w-full.min-h-11.px-3", text: "Sign out"
      assert_select "form[action=?][method=post]", session_path do
        assert_select "button", text: "Sign out"
        assert_select "input[type=hidden][name=_method][value=delete]"
      end
    end
    assert_select "details.sm\\:hidden:not(.relative)[data-close-on-outside]", 1 do
      assert_select "summary.min-h-11[class*='focus-visible:']" do
        assert_select "svg[viewBox='0 0 24 24'] path[d='M4 6l16 0']"
        assert_select "span.sr-only", text: "Open navigation menu"
      end
      assert_select "div.absolute.inset-x-0.top-full.w-full.z-20:not(.mt-2):not(.w-56)" do
        assert_select "div.mx-auto.max-w-6xl.px-5" do
          assert_select "nav[aria-label='Mobile navigation']", 1
          assert_select "a", text: "Dashboard", count: 0
          assert_select "div.mt-1 > [data-theme-toggle].w-full.justify-between[role=switch]", text: "Dark Mode", count: 1
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

  test "account menu uses full name or email when display name is absent" do
    user = users(:two)
    user.update!(first_name: "Sam", last_name: "Example")
    sign_in_as user

    get root_path
    assert_select "details.hidden.sm\\:block > summary", text: /Sam Example/

    user.update!(first_name: nil, last_name: nil)
    get root_path
    assert_select "details.hidden.sm\\:block > summary", text: /#{Regexp.escape(user.email_address)}/
  end

  test "long account name and email stay within the desktop menu" do
    user = users(:one)
    name = ("Very long account name " * 12).strip
    email = "#{'longusername' * 12}@example.com"
    user.update!(display_name: name, email_address: email)
    sign_in_as user

    get root_path

    assert_select "header > div.flex-wrap > div.sm\\:flex.min-w-0.max-w-full" do
      assert_select "details.min-w-0.max-w-full > summary.min-w-0.max-w-full" do
        assert_select "span.min-w-0.max-w-48.truncate[title=?]", name, text: name
      end
      assert_select "details > div.absolute.right-0.w-56[class~='max-w-[calc(100vw-2.5rem)]']" do
        assert_select "p.break-all", text: email
      end
    end
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
    assert_select "header [data-theme-toggle][type=button][role=switch][aria-label='Dark Mode'][aria-checked=false]", text: "Dark Mode", count: 1
    assert_select "header [data-theme-system]", 0
    assert_select "body.bg-amber-50.dark\\:bg-neutral-950"
    assert_select "header.bg-black.bg-linear-to-b.from-neutral-800.to-black:not(.shadow-md):not([class~='shadow-black/25'])"
    assert_select "header.border-b", 0
    assert_select "header span.text-green-300", text: "Mouthguard"
    assert_select "header a[href=?]", new_session_path, text: "Sign In"
    assert_select "header div.flex-wrap" do
      assert_select "[data-theme-toggle][role=switch]", text: "Dark Mode", count: 1
      assert_select "[data-theme-icon=off][aria-hidden=true] path[d='M6 12a2 2 0 1 0 4 0a2 2 0 1 0 -4 0']", 1
      assert_select "[data-theme-icon=on][aria-hidden=true][hidden] path[d='M14 12a2 2 0 1 0 4 0a2 2 0 1 0 -4 0']", 1
      assert_select "a[href=?]", new_session_path, text: "Sign In"
    end
    assert_select "header [data-theme-toggle].bg-green-300", 0
    assert_select "input[name='email_address'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[name='email_address'].border-green-800.focus\\:outline-green-800.dark\\:focus\\:outline-green-300", 1
    assert_select "input[name='password'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[type=submit].bg-green-800.dark\\:bg-green-300.dark\\:text-neutral-950:not(.bg-linear-to-b):not(.shadow-sm)", 1

    get new_password_path
    assert_select "header.bg-black"
    assert_select "header [data-theme-toggle]", 1
    assert_select "input[name='email_address'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[type=submit].bg-green-800.dark\\:bg-green-300.dark\\:text-neutral-950:not(.bg-linear-to-b):not(.shadow-sm)", 1

    get edit_password_path(users(:one).password_reset_token)
    assert_select "header.bg-black"
    assert_select "header [data-theme-toggle]", 1
    assert_select "input[name='password'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[name='password_confirmation'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[type=submit].bg-green-800.dark\\:bg-green-300.dark\\:text-neutral-950:not(.bg-linear-to-b):not(.shadow-sm)", 1
  end
end
