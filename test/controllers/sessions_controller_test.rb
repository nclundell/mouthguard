require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(@user)
    session_id = Current.session.id
    other_session = @user.sessions.create!
    server = ActionCable.server
    target = server.remote_connections.where(current_user: @user, session_id: session_id)
    other = server.remote_connections.where(current_user: @user, session_id: other_session.id)
    target_channel = "action_cable/#{target.connection_identifier}"
    other_channel = "action_cable/#{other.connection_identifier}"

    assert_broadcast_on(target_channel, type: "disconnect", reconnect: true) do
      delete session_path
    end

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
    assert_not Session.exists?(session_id)
    assert Session.exists?(other_session.id)
    assert_not_equal target_channel, other_channel
    assert_no_broadcasts other_channel
  end
end
