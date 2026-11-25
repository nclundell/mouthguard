require "test_helper"
require "turbo/broadcastable/test_helper"

class CommentTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  test "general comments replace the feed only on the dashboard" do
    game = Game.create!(cfbd_id: 13_002)
    comment = nil
    streams = capture_turbo_stream_broadcasts("dashboard_comments") do
      assert_turbo_stream_broadcasts "game_comments_#{game.id}", count: 0 do
        comment = Comment.create!(user: users(:one), body: "<p>Welcome everyone!</p>")
      end
    end

    assert_equal [ "replace" ], streams.map { |stream| stream["action"] }
    assert_equal "comments_feed", streams.first["target"]
    entry = streams.first.at_css("template li#comment_#{comment.id}[data-comment-id='#{comment.id}']")
    assert_equal "Welcome everyone!", entry.at_css(".break-words").text.strip
    assert_equal comment.user.email_address, entry.at_css(".font-semibold").text
    assert_equal comment.created_at.iso8601, entry.at_css("time")["datetime"]
  end

  test "game comments broadcast only to their own game's comments stream" do
    game = Game.create!(cfbd_id: 13_003)
    other = Game.create!(cfbd_id: 13_004)
    streams = capture_turbo_stream_broadcasts("game_comments_#{game.id}") do
      assert_turbo_stream_broadcasts "dashboard_comments", count: 0 do
        assert_turbo_stream_broadcasts "game_comments_#{other.id}", count: 0 do
          Comment.create!(user: users(:two), game: game, body: "Go team!")
        end
      end
    end

    assert_equal [ "replace" ], streams.map { |stream| stream["action"] }
    assert_equal "comments_feed", streams.first["target"]
    assert_equal "Go team!", streams.first.at_css("template li .break-words").text.strip
  end

  test "new general and game comments use the current season even when another season is supplied" do
    game = Game.create!(cfbd_id: 13_008)

    general = Comment.create!(user: users(:one), body: "General", season: Current.season - 1)
    game_comment = Comment.create!(user: users(:two), game: game, body: "Game", season: Current.season - 1)

    assert_equal Current.season, general.reload.season
    assert_equal Current.season, game_comment.reload.season
    assert_equal [general, game_comment], Comment.current.order(:id).to_a
  end

  test "live general feed excludes older and unseasoned comments from entries and pagination" do
    25.times { |i| Comment.create!(user: users(:one), body: "Current #{i}") }
    old = Comment.create!(user: users(:one), body: "Older season")
    legacy = Comment.create!(user: users(:one), body: "Unseasoned")
    old.update_column(:season, Current.season - 1)
    legacy.update_column(:season, nil)

    streams = capture_turbo_stream_broadcasts("dashboard_comments") do
      Comment.create!(user: users(:two), body: "Newest")
    end

    feed = streams.sole.at_css("template #comments_feed")
    assert_equal 25, feed.css("ol#comments_list > li").size
    assert_equal 1, feed.css("a[href='/?page=2#comments']").size
    assert_not_includes feed.text, "Older season"
    assert_not_includes feed.text, "Unseasoned"
  end

  test "live game feed excludes older comments for the same game" do
    game = Game.create!(cfbd_id: 13_009)
    old = Comment.create!(user: users(:one), game: game, body: "Older season")
    old.update_column(:season, Current.season - 1)

    streams = capture_turbo_stream_broadcasts("game_comments_#{game.id}") do
      Comment.create!(user: users(:two), game: game, body: "Current season")
    end

    feed = streams.sole.at_css("template #comments_feed")
    assert_equal 1, feed.css("ol#comments_list > li").size
    assert_not_includes feed.text, "Older season"
  end

  test "live dashboard feed stays at 25 and gains Older when the 26th arrives" do
    25.times { |i| Comment.create!(user: users(:one), body: "General #{i}") }
    game = Game.create!(cfbd_id: 13_005)
    Comment.create!(user: users(:two), game: game, body: "Not general")

    streams = capture_turbo_stream_broadcasts("dashboard_comments") do
      Comment.create!(user: users(:two), body: "Newest general")
    end

    feed = streams.sole.at_css("template #comments_feed")
    assert_equal 25, feed.css("ol#comments_list > li").size
    assert_equal "Newest general", feed.at_css("ol#comments_list > li .break-words").text.strip
    assert_equal 1, feed.css("a[href='/?page=2#comments']").size
    assert_not_includes feed.text, "Not general"
  end

  test "live game feed contains only its game's newest 25 and Older link" do
    game = Game.create!(cfbd_id: 13_006)
    other = Game.create!(cfbd_id: 13_007)
    25.times { |i| Comment.create!(user: users(:one), game: game, body: "Game #{i}") }
    Comment.create!(user: users(:one), game: other, body: "Other game")
    Comment.create!(user: users(:one), body: "General")

    streams = capture_turbo_stream_broadcasts("game_comments_#{game.id}") do
      Comment.create!(user: users(:two), game: game, body: "Newest game")
    end

    feed = streams.sole.at_css("template #comments_feed")
    assert_equal 25, feed.css("ol#comments_list > li").size
    assert_equal "Newest game", feed.at_css("ol#comments_list > li .break-words").text.strip
    assert_equal 1, feed.css("a[href='#{Rails.application.routes.url_helpers.game_path(game)}?page=2#comments']").size
    assert_not_includes feed.text, "Other game"
    assert_not_includes feed.text, "General"
  end

  test "rolled-back creations and updates do not broadcast comments" do
    comment = Comment.create!(user: users(:one), body: "Before")
    assert_turbo_stream_broadcasts "dashboard_comments", count: 0 do
      Comment.transaction do
        Comment.create!(user: users(:one), body: "Rolled back")
        raise ActiveRecord::Rollback
      end
      comment.update!(body: "After")
    end
  end

  test "a general comment belongs to its author without a game" do
    user = users(:one)
    comment = Comment.create!(user: user, body: "<p>Welcome everyone!</p>")

    assert_nil comment.reload.game
    assert_equal "Welcome everyone!", comment.body.to_plain_text
    assert_includes user.comments, comment
  end

  test "a game comment belongs to its game and author" do
    game = Game.create!(cfbd_id: 13000)
    user = users(:two)
    comment = Comment.create!(user: user, game: game, body: "<p>Go team!</p>")

    assert_equal game, comment.reload.game
    assert_includes game.comments, comment
    assert_includes user.comments, comment
  end

  test "an author is required" do
    comment = Comment.new(body: "Hello")

    assert_not comment.valid?
    assert_includes comment.errors[:user], "must exist"
  end

  test "empty rich text cannot be saved" do
    [ nil, "", "<p><br></p>", "<p>   </p>" ].each do |body|
      comment = Comment.new(user: users(:one), body: body)

      assert_not comment.valid?, "expected #{body.inspect} to be invalid"
      assert_includes comment.errors[:body], "can't be blank"
    end
  end

  test "ordinary file validation reads only a bounded prefix" do
    blob = upload_comment_blob("%PDF-1.4\n" + ("a" * 30.megabytes), "document.pdf", "application/pdf")
    comment = Comment.new(user: users(:one), body: attachment_for(blob))
    downloads = []
    subscriber = ActiveSupport::Notifications.subscribe(/service_(download|download_chunk)\.active_storage/) do |event, *, payload|
      downloads << [ event, payload[:range] ]
    end

    assert comment.valid?
    assert_equal [ [ "service_download_chunk.active_storage", 0..8191 ] ], downloads
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "actual image size over the cap rejects a falsely small non-image declaration without opening" do
    gif = "GIF89a" + ("\0" * 25.megabytes)
    blob = ActiveStorage::Blob.create_before_direct_upload!(
      filename: "document.pdf", content_type: "application/pdf", byte_size: 1,
      checksum: Base64.strict_encode64(Digest::MD5.digest(gif))
    )
    blob.service.upload(blob.key, StringIO.new(gif), checksum: blob.checksum)
    downloads = []
    subscriber = ActiveSupport::Notifications.subscribe(/service_(download|download_chunk)\.active_storage/) do |event, *, _payload|
      downloads << event
    end

    comment = Comment.new(user: users(:one), body: attachment_for(blob))
    assert_not comment.valid?
    assert_includes comment.errors[:body], "images must be 25 MB or smaller"
    assert downloads.any?
    assert downloads.all? { |event| event == "service_download_chunk.active_storage" }
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "whitespace-prefixed SVG is accepted but a falsely declared SVG is rejected" do
    svg = " \n\t<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>"
    valid_blob = upload_comment_blob(svg, "drawing.svg", "image/svg+xml")
    assert Comment.new(user: users(:one), body: attachment_for(valid_blob)).valid?

    pdf = "%PDF-1.4\nnot an svg"
    fake_blob = ActiveStorage::Blob.create_before_direct_upload!(
      filename: "drawing.svg", content_type: "image/svg+xml", byte_size: pdf.bytesize,
      checksum: Base64.strict_encode64(Digest::MD5.digest(pdf)), metadata: { identified: true }
    )
    fake_blob.service.upload(fake_blob.key, StringIO.new(pdf), checksum: fake_blob.checksum)
    comment = Comment.new(user: users(:one), body: attachment_for(fake_blob))
    assert_not comment.valid?
    assert_includes comment.errors[:body], "image upload metadata does not match the uploaded file"
  end

  test "image bytes declared as a non-image cannot be attached even when small" do
    gif = "GIF89a" + ("\0" * 100)
    blob = ActiveStorage::Blob.create_before_direct_upload!(
      filename: "document.pdf", content_type: "application/pdf", byte_size: gif.bytesize,
      checksum: Base64.strict_encode64(Digest::MD5.digest(gif)), metadata: { identified: true }
    )
    blob.service.upload(blob.key, StringIO.new(gif), checksum: blob.checksum)

    comment = Comment.new(user: users(:one), body: attachment_for(blob))
    assert_not comment.valid?
    assert_includes comment.errors[:body], "image upload metadata does not match the uploaded file"
  end

  test "destroying a user or game removes its comments" do
    user = users(:one)
    game = Game.create!(cfbd_id: 13001)
    game_comment = Comment.create!(user: user, game: game, body: "Game comment")
    general_comment = Comment.create!(user: user, body: "General comment")

    game.destroy!
    assert_not Comment.exists?(game_comment.id)
    assert Comment.exists?(general_comment.id)

    user.destroy!
    assert_not Comment.exists?(general_comment.id)
  end

  private

  def upload_comment_blob(bytes, filename, content_type)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: filename, content_type: content_type)
  end

  def attachment_for(blob)
    %(<p>Attachment</p><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>)
  end
end
