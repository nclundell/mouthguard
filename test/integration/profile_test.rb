require "test_helper"

class ProfileTest < ActionDispatch::IntegrationTest
  test "signed-in user sees only their own profile" do
    user = users(:one)
    user.update!(first_name: "Pat", last_name: "Example", display_name: "P. Example")
    sign_in_as user

    get profile_path

    assert_response :success
    assert_select "h1.border-pine-950.dark\\:border-pine-500", text: "My Profile"
    %w[one@example.com Pat Example P.\ Example].each do |value|
      assert_includes response.body, value
    end
    assert_select "main", text: /two@example.com/, count: 0
    assert_select "main a[href=?]", edit_profile_path, text: "Edit Profile"
  end

  test "edit profile has labeled fields and cancel navigation" do
    sign_in_as users(:one)

    get edit_profile_path

    assert_response :success
    assert_select "form[action=?][enctype='multipart/form-data']", profile_path do
      assert_select "input[name='user[email_address]'][type=email][required]"
      assert_select "div.py-4.sm\\:grid.sm\\:grid-cols-3.sm\\:gap-4", count: 8 do
        assert_select "label.font-medium.text-neutral-600.dark\\:text-neutral-300", count: 8
        assert_select "div.mt-1.break-words.sm\\:col-span-2.sm\\:mt-0", count: 8
      end
      assert_select "input[class~='w-full'][class~='p-0'][class~='bg-transparent'][class~='text-base'][class~='leading-6']", count: 7
      assert_select "label[for=user_avatar]", text: "Avatar"
      assert_select "input[name='user[avatar]'][type=file][accept='image/*']"
      %w[first_name last_name display_name].each do |field|
        assert_select "label[for='user_#{field}']"
        assert_select "input[name='user[#{field}]']"
      end
      assert_select "label[for=user_email_address]"
      assert_select "legend", text: "Change password (optional)"
      { current_password: "current-password", password: "new-password", password_confirmation: "new-password" }.each do |field, autocomplete|
        assert_select "label[for=user_#{field}]"
        assert_select "input[name='user[#{field}]'][type=password][autocomplete='#{autocomplete}'][value='']"
      end
      assert_select "input[type=submit][value='Save'].bg-pine-900.dark\\:bg-pine-700.dark\\:text-neutral-100"
    end
    assert_select "form svg.size-20[aria-hidden=true]", count: 1
    assert_select "main", text: /No photo/, count: 0
    assert_select "main a[href=?]", profile_path, text: "Cancel"
  end

  test "uploading an avatar attaches it and displays it on the edit page" do
    user = users(:one)
    sign_in_as user

    patch profile_path, params: { user: { avatar: fixture_file_upload("avatar.svg", "image/svg+xml") } }

    assert_redirected_to profile_path
    assert user.reload.avatar.attached?
    assert_equal "avatar.svg", user.avatar.filename.to_s

    get edit_profile_path

    assert_response :success
    assert_select "img[src*='/rails/active_storage/blobs/'][alt='Current avatar']", count: 1
    assert_select "main", text: /No photo/, count: 0
  end

  test "edit profile offers removal only when an avatar exists" do
    user = users(:one)
    sign_in_as user

    get edit_profile_path
    assert_select "input[name='user[remove_avatar]']", count: 0

    user.avatar.attach(fixture_file_upload("avatar.svg", "image/svg+xml"))
    get edit_profile_path

    assert_select "label[for=user_remove_avatar]", text: "Remove avatar"
    assert_select "input[name='user[remove_avatar]'][type=checkbox]"
    assert_select "img[alt='Current avatar']", count: 1
  end

  test "removing an avatar clears it on save" do
    user = users(:one)
    user.avatar.attach(fixture_file_upload("avatar.svg", "image/svg+xml"))
    sign_in_as user

    patch profile_path, params: { user: { remove_avatar: "1" } }

    assert_redirected_to profile_path
    assert_not user.reload.avatar.attached?
    get edit_profile_path
    assert_select "form svg.size-20[aria-hidden=true]", count: 1
    assert_select "input[name='user[remove_avatar]']", count: 0
  end

  test "replacement upload takes precedence over avatar removal" do
    user = users(:one)
    user.avatar.attach(fixture_file_upload("avatar.svg", "image/svg+xml"))
    sign_in_as user

    patch profile_path, params: { user: { remove_avatar: "1", avatar: fixture_file_upload("avatar.svg", "image/svg+xml") } }

    assert_redirected_to profile_path
    assert user.reload.avatar.attached?
  end

  test "failed update preserves avatar and its preview when removal is requested" do
    user = users(:one)
    user.avatar.attach(fixture_file_upload("avatar.svg", "image/svg+xml"))
    sign_in_as user

    patch profile_path, params: { user: { remove_avatar: "1", email_address: "invalid" } }

    assert_response :unprocessable_entity
    assert_select "img[alt='Current avatar']", count: 1
    assert user.reload.avatar.attached?
  end

  test "incorrect current password does not remove the avatar" do
    user = users(:one)
    user.avatar.attach(fixture_file_upload("avatar.svg", "image/svg+xml"))
    sign_in_as user

    patch profile_path, params: { user: { remove_avatar: "1", current_password: "wrong-password", password: "new-password", password_confirmation: "new-password" } }

    assert_response :unprocessable_entity
    assert_select "img[alt='Current avatar']", count: 1
    assert user.reload.avatar.attached?
    assert user.authenticate("password")
  end

  test "changing password and profile together requires current password" do
    user = users(:one)
    sign_in_as user
    current_session = Current.session
    other_session = user.sessions.create!

    patch profile_path, params: { user: { first_name: "Pat", current_password: "password", password: "new-password", password_confirmation: "new-password" } }

    assert_redirected_to profile_path
    assert_equal "Pat", user.reload.first_name
    assert user.authenticate("new-password")
    assert_not user.authenticate("password")
    assert_equal current_session, Current.session
    assert Session.exists?(current_session.id)
    assert_not Session.exists?(other_session.id)
  end

  test "incorrect or missing current password rejects all changes" do
    user = users(:one)
    sign_in_as user
    other_session = user.sessions.create!

    [ nil, "wrong-password" ].each do |current_password|
      patch profile_path, params: { user: { first_name: "Pat", current_password: current_password, password: "new-password", password_confirmation: "new-password" } }

      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: /Current password is incorrect or missing/
      assert_select "input[name='user[current_password]'][value='']"
      assert_select "input[name='user[password]'][value='']"
      assert_select "input[name='user[password_confirmation]'][value='']"
      assert_nil user.reload.first_name
      assert user.authenticate("password")
      assert_not user.authenticate("new-password")
      assert Session.exists?(other_session.id)
    end
  end

  test "mismatched or missing password confirmation rejects all changes" do
    user = users(:one)
    sign_in_as user
    other_session = user.sessions.create!

    [ "different", nil ].each do |confirmation|
      patch profile_path, params: { user: { first_name: "Pat", current_password: "password", password: "new-password", password_confirmation: confirmation } }

      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: /Password confirmation/
      assert_nil user.reload.first_name
      assert user.authenticate("password")
      assert_not user.authenticate("new-password")
      assert Session.exists?(other_session.id)
    end
  end

  test "invalid profile data does not change the password" do
    user = users(:one)
    sign_in_as user
    other_session = user.sessions.create!

    patch profile_path, params: { user: { email_address: "invalid", current_password: "password", password: "new-password", password_confirmation: "new-password" } }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Email address/
    assert_equal "one@example.com", user.reload.email_address
    assert user.authenticate("password")
    assert_not user.authenticate("new-password")
    assert Session.exists?(other_session.id)
  end

  test "blank new password ignores other password fields" do
    user = users(:one)
    sign_in_as user

    patch profile_path, params: { user: { first_name: "Pat", current_password: "wrong-password", password: "", password_confirmation: "ignored" } }

    assert_redirected_to profile_path
    assert_equal "Pat", user.reload.first_name
    assert user.authenticate("password")
  end

  test "updating profile changes only current user and redirects with notice" do
    sign_in_as users(:one)
    other_session = users(:one).sessions.create!

    patch profile_path, params: { user: { email_address: " PAT@EXAMPLE.COM ", first_name: "Pat", last_name: "Example", display_name: "P. Example" } }

    assert_redirected_to profile_path
    follow_redirect!
    assert_select "[role=status][class~='bg-pine-900'][class~='border-pine-900'][class~='text-neutral-100'][class~='dark:bg-pine-800']", text: /Profile updated/
    assert_equal "pat@example.com", users(:one).reload.email_address
    assert_equal %w[Pat Example], [ users(:one).first_name, users(:one).last_name ]
    assert_equal "P. Example", users(:one).display_name
    assert users(:one).authenticate("password")
    assert_equal "two@example.com", users(:two).reload.email_address
    assert Session.exists?(other_session.id)
  end

  test "invalid and duplicate emails render errors without updating user" do
    sign_in_as users(:one)

    [ "", "not-an-email", "two@example.com" ].each do |email|
      patch profile_path, params: { user: { email_address: email, first_name: "Changed" } }

      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: /Email address/
      assert_select "input[name='user[email_address]']"
      assert_equal "one@example.com", users(:one).reload.email_address
      assert_nil users(:one).first_name
    end
  end

  test "profile pages require authentication" do
    get profile_path
    assert_redirected_to new_session_path

    get edit_profile_path
    assert_redirected_to new_session_path

    patch profile_path, params: { user: { first_name: "Unauthenticated" } }
    assert_redirected_to new_session_path
    assert_nil users(:one).reload.first_name
  end

  test "profile is linked from account and mobile menus but not desktop navigation" do
    sign_in_as users(:one)

    get root_path

    assert_select "details.hidden.sm\\:block a[href=?]", profile_path, text: "My Profile", count: 1
    assert_select "details.sm\\:hidden a[href=?]", profile_path, text: "My Profile", count: 1
    assert_select "nav[aria-label='Main navigation'] a[href=?]", profile_path, count: 0
  end
end
