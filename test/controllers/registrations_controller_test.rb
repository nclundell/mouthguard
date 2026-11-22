require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "sign up form is public and linked from sign in" do
    get new_session_path
    assert_select "a[href=?]", new_registration_path, text: "Sign up"

    get new_registration_path
    assert_response :success
    assert_select "form[action=?]", registration_path do
      assert_select "input[name='user[email_address]'][type=email]"
      assert_select "input[name='user[display_name]']"
      assert_select "input[name='user[password]'][type=password]"
      assert_select "input[name='user[password_confirmation]'][type=password]"
    end
  end

  test "signing up starts a session without seeding picks" do
    current_game = Game.create!(cfbd_id: Game.maximum(:cfbd_id).to_i + 1, season: Current.season)
    other_game = Game.create!(cfbd_id: current_game.cfbd_id + 1, season: Current.season - 1)

    assert_no_difference "Pick.count" do
      assert_difference [ "User.count", "Session.count" ], 1 do
        post registration_path, params: { user: signup_attributes }
      end
    end

    assert_redirected_to root_path
    user = User.find_by!(email_address: "new@example.com")
    assert_equal "New Player", user.display_name
    assert user.authenticate("secret-password")
    assert_equal user, Session.find_by!(id: signed_session_id).user
    assert_empty user.picks
    assert_not user.picks.exists?(game: other_game)
  end

  test "invalid and duplicate registrations retain model errors without sessions or picks" do
    [ signup_attributes(password_confirmation: "different"),
      signup_attributes(password_confirmation: nil),
      signup_attributes(password: ""),
      signup_attributes(email_address: "not-an-email"),
      signup_attributes(email_address: users(:one).email_address) ].each do |attributes|
      assert_no_difference [ "User.count", "Session.count", "Pick.count" ] do
        post registration_path, params: { user: attributes }
      end

      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: /Password|Email address/
      assert_select "input[name='user[email_address]'][value=?]", attributes[:email_address]
      assert_select "input[name='user[password]'][value='']"
      assert_select "input[name='user[password_confirmation]'][value='']"
      assert_nil cookies[:session_id]
    end
  end

  private
    def signup_attributes(**overrides)
      { email_address: "new@example.com", display_name: "New Player",
        password: "secret-password", password_confirmation: "secret-password" }.merge(overrides)
    end

    def signed_session_id
      ActionDispatch::TestRequest.create.tap { |request| request.cookie_jar["session_id"] = cookies[:session_id] }
        .cookie_jar.signed[:session_id]
    end
end
