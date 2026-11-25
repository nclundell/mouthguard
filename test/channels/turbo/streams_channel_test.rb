require "test_helper"

class Turbo::StreamsChannelTest < ActionCable::Channel::TestCase
  tests Turbo::StreamsChannel

  test "repeated preparation does not stack stream authorization modules" do
    Rails.application.reloader.prepare!
    Rails.application.reloader.prepare!

    assert_equal 1, Turbo::StreamsChannel.ancestors.count { |ancestor| ancestor == DashboardStreamAuthorization }
  end

  test "guest receives public dashboard updates" do
    stub_connection(current_user: nil)
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ "dashboard_games" ])

    assert subscription.confirmed?
    assert_has_stream "dashboard_games"
    assert_broadcast_on "dashboard_games", "<turbo-stream action='replace'></turbo-stream>" do
      ActionCable.server.broadcast "dashboard_games", "<turbo-stream action='replace'></turbo-stream>"
    end
  end

  test "guest cannot subscribe to other signed streams" do
    stub_connection(current_user: nil)
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ "private:user" ])

    assert subscription.rejected?
    assert_no_streams
  end

  test "guest cannot subscribe to the games stream" do
    stub_connection(current_user: nil)
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ "games" ])

    assert subscription.rejected?
    assert_no_streams
  end

  test "guest cannot subscribe to signed comments streams" do
    stub_connection(current_user: nil)
    [ "dashboard_comments", "game_comments_123" ].each do |stream|
      subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ stream ])
      assert subscription.rejected?
      assert_no_streams
    end
  end

  test "guest cannot subscribe with an invalid signature" do
    stub_connection(current_user: nil)
    subscribe signed_stream_name: "dashboard_games"

    assert subscription.rejected?
    assert_no_streams
  end

  test "signed-in user can still subscribe to game streams" do
    stub_connection(current_user: users(:one))
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ "games" ])

    assert subscription.confirmed?
    assert_has_stream "games"

    game = Game.create!(cfbd_id: 92_014)
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ game ])

    assert subscription.confirmed?
    assert_has_stream game.to_gid_param
  end
end
