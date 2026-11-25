require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "guests can connect without a user" do
    connect

    assert_nil connection.current_user
    assert_nil connection.session_id
  end

  test "signed-in users retain their identity" do
    user = users(:one)
    session = user.sessions.create!(user_agent: "test", ip_address: "127.0.0.1")
    cookies.signed[:session_id] = session.id

    connect

    assert_equal user, connection.current_user
    assert_equal session.id, connection.session_id
  end

  test "invalid session cookies do not authenticate a connection" do
    cookies.signed[:session_id] = -1

    connect

    assert_nil connection.current_user
    assert_nil connection.session_id
  end
end
