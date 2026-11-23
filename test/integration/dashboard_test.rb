require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  test "desktop navigation lists picks before games" do
    sign_in_as users(:one)

    get root_path

    assert_response :success
    assert_select "header nav[aria-label='Main navigation'] > a" do |links|
      assert_equal %w[Games Picks Leaders Legends], links.map(&:text)
    end
  end

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
    assert_select "header a.text-neutral-100[class~='hover:text-pine-400']", text: "Mouthguard"
    assert_select "header a[href=?] > svg[data-icon=mouthguard][aria-hidden=true] + span", root_path, text: "Mouthguard", count: 1
    assert_select "header a[href=?] > svg.size-8.text-amber-500[viewBox='0 0 24 24'][fill=currentColor] path[d='M2 5a2 2 0 0 1 4 0v4a6 6 0 0 0 12 0V5a2 2 0 0 1 4 0v4A10 10 0 0 1 2 9V5Z']", root_path, count: 1
    assert_select "h1.border-pine-950.dark\\:border-pine-500", text: "Dashboard"
    assert_select "head script[src*='theme']", 1
    assert_select "header [data-theme-toggle][type=button][role=switch][aria-label='Dark Mode'][title='Toggle dark mode'][aria-checked=false]", 1
    assert_select "header [data-theme-toggle].size-11:not(.w-full):not(.bg-pine-400)[class*='hover:'][class*='focus-visible:']", 1
    assert_select "header [data-theme-toggle] > span", 0
    assert_select "header [data-theme-toggle] > svg[data-theme-icon=off].text-pine-400[aria-hidden=true]:not([hidden]) path[d='M12 3c.132 0 .263 0 .393 0a7.5 7.5 0 0 0 7.92 12.446a9 9 0 1 1 -8.313 -12.454l0 .008']", 1
    assert_select "header [data-theme-toggle] > svg[data-theme-icon=on].text-pine-400[aria-hidden=true][hidden] path[d='M8 12a4 4 0 1 0 8 0a4 4 0 1 0 -8 0']", 1
    assert_select "header > div.flex-wrap > div.items-center.gap-2" do
      assert_select "> [data-theme-toggle]", 1
      assert_select "> div.sm\\:flex > details > summary", 1
      assert_select "> details.sm\\:hidden > summary", 1
    end
    assert_select "header [data-theme-system]", 0
    assert_select "header a[href=?]", root_path, text: "Mouthguard"
    assert_select "header nav[aria-label='Main navigation']", 1
    assert_select "header a", text: "Dashboard", count: 0
    assert_select "details.hidden.sm\\:block[data-close-on-outside]", 1 do
      assert_select "summary.h-11.w-40.border.border-transparent.text-neutral-100[class~='hover:border-pine-500'][class~='hover:bg-neutral-800']:not(.bg-pine-900):not(.bg-pine-950):not([class~='border-pine-900'])[class*='focus-visible:']", text: /Pat Example/
      assert_select "summary > span.min-w-0.flex-1.truncate[title='Pat Example']", text: "Pat Example"
      assert_select "summary > svg:first-child.size-6.shrink-0[aria-hidden=true] path[d='M6.168 18.849a4 4 0 0 1 3.832 -2.849h4a4 4 0 0 1 3.834 2.855']", count: 1
      assert_select "summary > img", count: 0
      assert_select "summary svg[aria-hidden='true'] path[d='M6 9l6 6l6 -6']"
      assert_select "[data-theme-toggle]", 0
      assert_select "div.absolute.w-56 > form > button.w-full.min-h-11.px-3", text: "Sign out"
      assert_select "form[action=?][method=post]", session_path do
        assert_select "button", text: "Sign out"
        assert_select "input[type=hidden][name=_method][value=delete]"
      end
    end
    assert_select "details.sm\\:hidden:not(.relative)[data-close-on-outside]", 1 do
      assert_select "summary.size-11:not(.w-48)[class*='focus-visible:']" do
        assert_select "svg[viewBox='0 0 24 24'] path[d='M4 6l16 0']"
        assert_select "span.sr-only", text: "Open navigation menu"
      end
      assert_select "div.absolute.inset-x-0.top-full.w-full.z-20:not(.mt-2):not(.w-56)" do
        assert_select "div.mx-auto.max-w-6xl.px-5" do
          assert_select "nav[aria-label='Mobile navigation']", 1
          assert_select "a", text: "Dashboard", count: 0
          assert_select "[data-theme-toggle]", 0
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

  test "desktop account summary displays an attached avatar before the name" do
    user = users(:one)
    user.avatar.attach(fixture_file_upload("avatar.svg", "image/svg+xml"))
    sign_in_as user

    get root_path

    assert_response :success
    assert_select "details.hidden.sm\\:block > summary" do
      assert_select "img:first-child.size-6.shrink-0.rounded-full.object-cover[alt=''][src*='/rails/active_storage/blobs/']", count: 1
      assert_select "svg.size-6", count: 0
      assert_select "span.truncate", text: user.email_address
    end
    assert_select "details.sm\\:hidden > summary svg path[d='M4 6l16 0']", count: 1
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

  test "long account names stay within the account menus" do
    user = users(:one)
    name = ("Very long account name " * 12).strip
    user.update!(display_name: name)
    sign_in_as user

    get root_path

    assert_select "header > div.flex-wrap > div.items-center.gap-2 > div.sm\\:flex.min-w-0.max-w-full" do
      assert_select "details.min-w-0.max-w-full > summary.h-11.w-40" do
        assert_select "span.min-w-0.flex-1.truncate[title=?]", name, text: name
      end
      assert_select "details > div.absolute.right-0.w-56[class~='max-w-[calc(100vw-2.5rem)]']"
    end
    assert_select "details.sm\\:hidden > div > div > div.flex.items-center.gap-2" do
      assert_select "> svg.size-6.shrink-0[aria-hidden=true]", count: 1
      assert_select "> span.min-w-0.flex-1.truncate[title=?]", name, text: name
    end
  end

  test "anonymous visitor is redirected to sign in" do
    get root_path

    assert_redirected_to new_session_path
  end

  test "mouthguard asset leaves size and color to the view" do
    assert_not File.exist?(Rails.root.join("app/assets/svg/icons/tabler/filled/mouthguard.svg"))
    asset = Nokogiri::XML(File.read(Rails.root.join("app/assets/svg/icons/custom/mouthguard.svg"))) { |config| config.strict }
    svg = asset.root

    assert_equal "0 0 24 24", svg["viewBox"]
    assert_equal "currentColor", svg["fill"]
    assert_nil svg["width"]
    assert_nil svg["height"]
    assert_nil svg["class"]
    assert_equal "M2 5a2 2 0 0 1 4 0v4a6 6 0 0 0 12 0V5a2 2 0 0 1 4 0v4A10 10 0 0 1 2 9V5Z", svg.at_xpath("./*[local-name()='path']")["d"]
    refute_match(/#[0-9a-fA-F]{3,8}\b|\b(?:white|black|amber)\b/, asset.to_xml)
  end

  test "anonymous sign in and password forms offer theme controls and dark inputs" do
    get new_session_path

    assert_response :success
    assert_select "body.bg-linear-to-b[class~='from-amber-50'][class~='to-[#f5efdf]'][class~='dark:from-neutral-900'][class~='dark:to-neutral-950']", 1
    assert_select "main.bg-linear-to-b", 0
    assert_select "header [data-theme-toggle][type=button][role=switch][aria-label='Dark Mode'][title='Toggle dark mode'][aria-checked=false]", 1
    assert_select "header [data-theme-system]", 0
    assert_select "body.bg-amber-50.dark\\:bg-neutral-950"
    assert_select "header.bg-black.bg-linear-to-b.from-neutral-800.to-black:not(.shadow-md):not([class~='shadow-black/25'])"
    assert_select "header.border-b", 0
    assert_select "header span.text-neutral-100", text: "Mouthguard"
    assert_select "header a.h-11.w-40.justify-center.border-pine-600.text-neutral-100[href=?]", new_session_path, text: "Sign In"
    assert_select "header div.flex-wrap" do
      assert_select "> [data-theme-toggle].size-11[class*='focus-visible:'][role=switch]", 1
      assert_select "[data-theme-icon=off][aria-hidden=true]:not([hidden]) path[d='M12 3c.132 0 .263 0 .393 0a7.5 7.5 0 0 0 7.92 12.446a9 9 0 1 1 -8.313 -12.454l0 .008']", 1
      assert_select "[data-theme-icon=on][aria-hidden=true][hidden] path[d='M8 12a4 4 0 1 0 8 0a4 4 0 1 0 -8 0']", 1
      assert_select "a[href=?]", new_session_path, text: "Sign In"
    end
    assert_select "header [data-theme-toggle].bg-pine-400", 0
    assert_select "input[name='email_address'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[name='email_address'].border-pine-950.focus\\:outline-pine-950.dark\\:focus\\:outline-pine-400", 1
    assert_select "input[name='password'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[type=submit].bg-pine-900.dark\\:bg-pine-700.dark\\:text-neutral-100:not(.bg-linear-to-b):not(.shadow-sm)", 1

    get new_password_path
    assert_select "header.bg-black"
    assert_select "header [data-theme-toggle]", 1
    assert_select "input[name='email_address'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[type=submit].bg-pine-900.dark\\:bg-pine-700.dark\\:text-neutral-100:not(.bg-linear-to-b):not(.shadow-sm)", 1

    get edit_password_path(users(:one).password_reset_token)
    assert_select "header.bg-black"
    assert_select "header [data-theme-toggle]", 1
    assert_select "input[name='password'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[name='password_confirmation'].dark\\:bg-neutral-800.dark\\:border-neutral-400.dark\\:text-neutral-100.dark\\:placeholder\\:text-neutral-400", 1
    assert_select "input[type=submit].bg-pine-900.dark\\:bg-pine-700.dark\\:text-neutral-100:not(.bg-linear-to-b):not(.shadow-sm)", 1
  end
end
