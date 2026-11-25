require "test_helper"

class CommentsTest < ActionDispatch::IntegrationTest
  test "signed-in dashboard shows general comments newest first and a Lexxy form" do
    older = Comment.create!(user: users(:one), body: "Older general comment")
    newer = Comment.create!(user: users(:two), body: "Newer general comment")
    game = Game.create!(cfbd_id: 95_001)
    Comment.create!(user: users(:one), game: game, body: "Game-only comment")
    sign_in_as users(:one)

    get root_path

    assert_response :success
    assert_select "main > section[aria-labelledby=next-move-heading] > #next-move-heading", count: 1
    assert_select "main > section[aria-labelledby=next-move-heading] + section[data-comments]", count: 1
    assert_select "section[data-comments] [data-comment-id]" do |items|
      assert_equal [newer.id, older.id].map(&:to_s), items.map { |item| item["data-comment-id"] }
      assert_equal [newer, older].map { |entry| "comment_#{entry.id}" }, items.map { |item| item["id"] }
    end
    assert_select "section[data-comments] ol#comments_list > li", count: 2
    assert_equal [ "dashboard_comments" ], comment_stream_names
    assert_select "section[data-comments]", text: /Game-only comment/, count: 0
    assert_select "section[data-comments] form[action=?][method=post]", comments_path do
      assert_select "label[for=comment_body].sr-only", text: "Your comment"
      assert_select "lexxy-editor[name='comment[body]'][data-direct-upload-url]", count: 1
      assert_select "input[type=submit][value='Post comment']"
    end
    importmap = JSON.parse(css_select('script[type="importmap"]').sole.text)
    assert_match %r{\A/assets/activestorage\.esm-[^"]+\.js\z}, importmap.fetch("imports").fetch("@rails/activestorage")
    assert_select "section[data-comments] form + #comments_feed", count: 1
    assert_select "section[data-comments] time[datetime]", count: 2
    assert_select "section[data-comments]", text: /one@example.com|two@example.com/
  end

  test "guest dashboard omits the entire comments section" do
    Comment.create!(user: users(:one), body: "Private general comment")

    get root_path

    assert_response :success
    assert_select "section[data-comments]", count: 0
    assert_select "main", text: /Private general comment/, count: 0
    assert_not_includes comment_stream_names, "dashboard_comments"
  end

  test "dashboard pages exclude older and unseasoned general comments" do
    old = Comment.create!(user: users(:one), body: "Older season")
    legacy = Comment.create!(user: users(:one), body: "Unseasoned")
    old.update_column(:season, Current.season - 1)
    legacy.update_column(:season, nil)
    current = Comment.create!(user: users(:one), body: "Current season")
    sign_in_as users(:one)

    get root_path(page: 2)

    assert_select "section[data-comments] [data-comment-id]" do |items|
      assert_equal [current.id.to_s], items.map { |item| item["data-comment-id"] }
    end
    assert_select "section[data-comments] a", text: "Older", count: 0
  end

  test "game show excludes older and unseasoned comments for the same game" do
    game = Game.create!(cfbd_id: 95_015)
    old = Comment.create!(user: users(:one), game: game, body: "Older season")
    legacy = Comment.create!(user: users(:one), game: game, body: "Unseasoned")
    old.update_column(:season, Current.season - 1)
    legacy.update_column(:season, nil)
    current = Comment.create!(user: users(:one), game: game, body: "Current season")
    sign_in_as users(:one)

    get game_path(game)

    assert_select "section[data-comments] [data-comment-id]" do |items|
      assert_equal [current.id.to_s], items.map { |item| item["data-comment-id"] }
    end
  end

  test "signed-in dashboard shows an empty conversation when there are no comments" do
    sign_in_as users(:one)

    get root_path

    assert_select "section[data-comments]", text: /No comments yet\. Start the conversation\./
    assert_select "section[data-comments] ol#comments_list", count: 1
    assert_select "section[data-comments] ol#comments_list li", count: 0
    assert_select "section[data-comments] #comments_empty", count: 1
    assert_equal [ "dashboard_comments" ], comment_stream_names
  end

  test "game show displays only that game's comments even when picks are hidden" do
    game = Game.create!(cfbd_id: 95_002, start: 1.day.from_now)
    other = Game.create!(cfbd_id: 95_003)
    comment = Comment.create!(user: users(:one), game: game, body: "This game comment")
    Comment.create!(user: users(:two), game: other, body: "Other game comment")
    Comment.create!(user: users(:one), body: "General comment")
    sign_in_as users(:two)

    get game_path(game)

    assert_response :success
    assert_select "[data-picks-side] p", text: "Picks hidden until kickoff", count: 2
    assert_select "[data-picks-layout] > [data-game-content]:nth-child(2) > section#game_hero_#{game.id} + section[data-comments]", count: 1
    assert_select "[data-picks-layout] > section[data-comments]", count: 0
    assert_select "section[data-comments] [data-comment-id=?]", comment.id.to_s, count: 1
    assert_equal [ "game_comments_#{game.id}" ], comment_stream_names
    assert_select "section[data-comments]", text: /Other game comment|General comment/, count: 0
    assert_select "section[data-comments] form[action=?]", game_comments_path(game) do
      assert_select "lexxy-editor[name='comment[body]']", count: 1
    end
    assert_select "section[data-comments] form + #comments_feed", count: 1
  end

  test "posting general comments uses the signed-in user and never accepts a game or user from params" do
    game = Game.create!(cfbd_id: 95_004)
    sign_in_as users(:one)

    assert_difference "Comment.count", 1 do
      post comments_path, params: { comment: { body: "<p>General post</p>", user_id: users(:two).id, game_id: game.id } }
    end

    assert_redirected_to root_path
    assert_equal "Comment posted.", flash[:notice]
    assert_equal users(:one), Comment.last.user
    assert_nil Comment.last.game
    assert_equal "General post", Comment.last.body.to_plain_text
    follow_redirect!
    assert_select "ol#comments_list li#comment_#{Comment.last.id}", count: 1
  end

  test "posting game comments uses the nested game and signed-in user" do
    game = Game.create!(cfbd_id: 95_005)
    other = Game.create!(cfbd_id: 95_006)
    sign_in_as users(:one)

    assert_difference "Comment.count", 1 do
      post game_comments_path(game), params: { comment: { body: "Game post", user_id: users(:two).id, game_id: other.id } }
    end

    assert_redirected_to game_path(game)
    assert_equal "Comment posted.", flash[:notice]
    assert_equal users(:one), Comment.last.user
    assert_equal game, Comment.last.game
    follow_redirect!
    assert_select "ol#comments_list li#comment_#{Comment.last.id}", count: 1
  end

  test "a directly uploaded GIF can be posted as a comment attachment" do
    sign_in_as users(:one)
    gif = Base64.decode64("R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=")
    checksum = Base64.strict_encode64(Digest::MD5.digest(gif))

    post rails_direct_uploads_path, params: {
      blob: { filename: "picture.gif", content_type: "image/gif", byte_size: gif.bytesize, checksum: checksum }
    }, as: :json

    assert_response :success
    upload = response.parsed_body
    put upload.fetch("direct_upload").fetch("url"), params: gif,
      headers: upload.fetch("direct_upload").fetch("headers")
    assert_response :success

    attachment = %(<action-text-attachment sgid="#{upload.fetch("attachable_sgid")}" content-type="image/gif" filename="picture.gif"></action-text-attachment>)
    assert_difference "Comment.count", 1 do
      post comments_path, params: { comment: { body: "<p>Picture</p>#{attachment}" } }
    end

    assert_redirected_to root_path
    comment = Comment.last
    assert_equal "picture.gif", comment.body.embeds.sole.filename.to_s
    assert_equal gif, comment.body.embeds.sole.download

    follow_redirect!
    assert_response :success
    images = css_select("section[data-comments] li#comment_#{comment.id} .lexxy-content figure.attachment--gif img[src]")
    assert_equal 1, images.size
    assert_equal "picture.gif", images.sole["alt"]
    assert_select "li#comment_#{comment.id} figure.attachment--gif figcaption.attachment__caption", count: 0
    assert_select "li#comment_#{comment.id} figure.attachment--gif .attachment__name", count: 0
    image_url = URI.parse(images.sole["src"])
    assert_match %r{\A/rails/active_storage/blobs/}, image_url.path
    get image_url.to_s
    follow_redirect! if response.redirect?
    assert_response :success
    assert_equal "image/gif", response.media_type
    assert_equal gif, response.body
  end

  test "comment images and GIFs display at 10 MB and require activation above 10 MB" do
    sign_in_as users(:one)
    [ "image/png", "image/gif" ].each do |type|
      [ 10.megabytes, 10.megabytes + 1, 25.megabytes ].each do |size|
        blob = image_blob(type, size)
        attachment = %(<action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>)
        post comments_path, params: { comment: { body: "<p>Picture</p>#{attachment}" } }
        assert_redirected_to root_path
        get root_path
        assert_response :success
        selector = "li#comment_#{Comment.last.id} figure"
        assert_select "#{selector} figcaption.attachment__caption", count: 0
        assert_select "#{selector} .attachment__name", count: 0
        if size <= 10.megabytes
          assert_select "#{selector} img.comment-attachment-image[src*='/rails/active_storage/blobs/']", count: 1
          assert_select "#{selector} button", count: 0
        else
          assert_select "#{selector} img[src]", count: 0
          assert_select "#{selector} button[type=button][data-controller=reveal-image][data-reveal-image-url-value*='/rails/active_storage/blobs/']",
            text: "Show #{type == "image/gif" ? "GIF" : "image"} (#{ActiveSupport::NumberHelper.number_to_human_size(size)})", count: 1
          assert_select "#{selector} button.comment-image-reveal", text: /picture\.(gif|png)/, count: 0
        end
      end
    end
  end

  test "direct upload initialization rejects oversized images but allows 25 MB images and other files" do
    sign_in_as users(:one)
    [ [ "image/gif", 25.megabytes, :success ],
      [ "image/png", 25.megabytes + 1, :unprocessable_entity ],
      [ "application/pdf", 25.megabytes + 1, :success ] ].each do |type, size, expected|
      assert_difference "ActiveStorage::Blob.count", expected == :success ? 1 : 0 do
        post rails_direct_uploads_path, params: { blob: {
          filename: "file", content_type: type, byte_size: size,
          checksum: Base64.strict_encode64(Digest::MD5.digest("file"))
        } }, as: :json
      end
      assert_response expected
      assert_match(/25 MB/, response.parsed_body.fetch("error")) if expected == :unprocessable_entity
    end
  end

  test "a pre-existing oversized image cannot be attached to a comment" do
    sign_in_as users(:one)
    blob = image_blob("image/gif", 25.megabytes + 1)
    attachment = %(<action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>)

    assert_no_difference "Comment.count" do
      post comments_path, params: { comment: { body: "<p>Picture</p>#{attachment}" } }, as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_select "turbo-stream template [role=alert]", text: /25 MB/
    assert_select "turbo-stream template lexxy-editor[aria-invalid=true]"
  end

  test "uploaded bytes cannot masquerade as a small image or a large non-image file" do
    sign_in_as users(:one)
    gif = Base64.decode64("R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=") + ("\0" * 25.megabytes)
    [
      { filename: "small.gif", content_type: "image/gif", byte_size: 1 },
      { filename: "document.pdf", content_type: "application/pdf", byte_size: 1 }
    ].each do |declaration|
      blob = ActiveStorage::Blob.create_before_direct_upload!(
        **declaration, checksum: Base64.strict_encode64(Digest::MD5.digest(gif))
      )
      blob.service.upload(blob.key, StringIO.new(gif), checksum: blob.checksum)

      assert_no_difference "Comment.count" do
        post comments_path, params: { comment: {
          body: %(<p>Picture</p><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>)
        } }, as: :turbo_stream
      end
      assert_response :unprocessable_entity
      assert_select "turbo-stream template [role=alert]", text: /25 MB/
      assert_empty ActiveStorage::Attachment.where(record_type: "ActionText::RichText", name: "embeds").where(blob_id: blob.id)
    end
  end

  test "raw image markup cannot appear in a posted comment or feed" do
    sign_in_as users(:one)
    assert_no_difference "Comment.count" do
      post comments_path, params: { comment: { body: '<p>Hi</p><img src="https://example.com/tracker.gif">' } }, as: :turbo_stream
    end
    assert_response :unprocessable_entity
    assert_select "turbo-stream template [role=alert]", text: /images/i
    get root_path
    assert_select "section[data-comments] img[src='https://example.com/tracker.gif']", count: 0
  end

  test "raw reveal controls cannot be injected into comments" do
    sign_in_as users(:one)
    assert_no_difference "Comment.count" do
      post comments_path, params: { comment: {
        body: '<p>Hi</p><button type="button" data-controller="reveal-image" data-reveal-image-url-value="/rails/active_storage/blobs/fake">Show</button>'
      } }, as: :turbo_stream
    end
    assert_response :unprocessable_entity
    assert_select "turbo-stream template [role=alert]", text: /attachments/
  end

  test "declared image containing another file type cannot be attached" do
    sign_in_as users(:one)
    pdf = "%PDF-1.4\n" + ("some content\n" * 4)
    blob = ActiveStorage::Blob.create_before_direct_upload!(
      filename: "picture.gif", content_type: "image/gif", byte_size: pdf.bytesize,
      checksum: Base64.strict_encode64(Digest::MD5.digest(pdf)), metadata: { identified: true }
    )
    blob.service.upload(blob.key, StringIO.new(pdf), checksum: blob.checksum)

    assert_no_difference "Comment.count" do
      post comments_path, params: { comment: {
        body: %(<p>Picture</p><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>)
      } }, as: :turbo_stream
    end
    assert_response :unprocessable_entity
    assert_select "turbo-stream template [role=alert]", text: /metadata/
  end

  test "ordinary file attachments still post and render as files" do
    sign_in_as users(:one)
    pdf = "%PDF-1.4\nfile contents"
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(pdf), filename: "document.pdf", content_type: "application/pdf"
    )

    assert_difference "Comment.count", 1 do
      post comments_path, params: { comment: {
        body: %(<p>Document</p><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>)
      } }
    end
    follow_redirect!
    assert_select "li#comment_#{Comment.last.id} figure.attachment--pdf button.comment-image-reveal", count: 0
  end

  test "whitespace-prefixed SVG can be attached and uses the image display policy" do
    sign_in_as users(:one)
    svg = " \n<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>"
    blob = ActiveStorage::Blob.create_before_direct_upload!(
      filename: "drawing.svg", content_type: "image/svg+xml", byte_size: svg.bytesize,
      checksum: Base64.strict_encode64(Digest::MD5.digest(svg))
    )
    blob.service.upload(blob.key, StringIO.new(svg), checksum: blob.checksum)

    assert_difference "Comment.count", 1 do
      post comments_path, params: { comment: {
        body: %(<p>Drawing</p><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>)
      } }
    end
    follow_redirect!
    assert_select "li#comment_#{Comment.last.id} img.comment-attachment-image[src*='/rails/active_storage/blobs/']", count: 1
    assert_select "li#comment_#{Comment.last.id} button.comment-image-reveal", count: 0
  end

  test "blank posts show an error and create no comment" do
    sign_in_as users(:one)

    assert_no_difference "Comment.count" do
      post comments_path, params: { comment: { body: "" } }
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_select "section[data-comments] [role=alert]", text: /Body can't be blank/
  end

  test "blank game posts return to the game with a visible error" do
    game = Game.create!(cfbd_id: 95_008)
    sign_in_as users(:one)

    assert_no_difference "Comment.count" do
      post game_comments_path(game), params: { comment: { body: "<p><br></p>" } }
    end

    assert_redirected_to game_path(game)
    follow_redirect!
    assert_select "section[data-comments] [role=alert]", text: /Body can't be blank/
  end

  test "invalid Turbo rich text post replaces the game comments and retains its editor" do
    game = Game.create!(cfbd_id: 95_009)
    existing = Comment.create!(user: users(:one), game: game, body: "Existing game comment")
    sign_in_as users(:one)

    assert_no_difference "Comment.count" do
      post game_comments_path(game), params: { comment: { body: "<p><br></p>" } }, as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_match(/<turbo-stream action="replace" target="comments">/, response.body)
    assert_select "turbo-stream template section#comments[data-comments]" do
      assert_select "[data-comment-id=?]", existing.id.to_s
      assert_select "[role=alert]", text: /Body can't be blank/
      assert_select "lexxy-editor[name='comment[body]'][aria-invalid=true][aria-describedby=comment-errors]", count: 1
    end
  end

  test "invalid Turbo game post excludes older comments from the replacement" do
    game = Game.create!(cfbd_id: 95_016)
    old = Comment.create!(user: users(:one), game: game, body: "Older season")
    old.update_column(:season, Current.season - 1)
    current = Comment.create!(user: users(:one), game: game, body: "Current season")
    sign_in_as users(:one)

    post game_comments_path(game), params: { comment: { body: "" } }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream template section#comments [data-comment-id]" do |items|
      assert_equal [current.id.to_s], items.map { |item| item["data-comment-id"] }
    end
  end

  test "invalid Turbo dashboard post keeps the general comments form" do
    existing = Comment.create!(user: users(:one), body: "Existing general comment")
    sign_in_as users(:one)

    assert_no_difference "Comment.count" do
      post comments_path, params: { comment: { body: "<p><br></p>" } }, as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=replace][target=comments] template section#comments" do
      assert_select "[data-comment-id=?]", existing.id.to_s
      assert_select "[role=alert]", text: /Body can't be blank/
      assert_select "form[action=?] lexxy-editor[name='comment[body]']", comments_path, count: 1
    end
  end

  test "dashboard comments page by newest first without including game comments" do
    game = Game.create!(cfbd_id: 95_010)
    comments = 27.times.map { |i| Comment.create!(user: users(:one), body: "General #{i}") }
    Comment.create!(user: users(:one), game: game, body: "Game-only comment")
    sign_in_as users(:one)

    get root_path
    assert_select "section[data-comments] [data-comment-id]" do |items|
      assert_equal comments.last(25).reverse.map { |entry| entry.id.to_s }, items.map { |item| item["data-comment-id"] }
    end
    assert_select "section[data-comments] a", text: "Older", count: 1, attributes: { href: root_path(page: 2, anchor: "comments") }
    assert_select "section[data-comments] a", text: "Newer", count: 0
    assert_select "section[data-comments]", text: /Game-only comment/, count: 0

    get root_path(page: 2)
    assert_empty comment_stream_names
    assert_select "section[data-comments] [data-comment-id]" do |items|
      assert_equal comments.first(2).reverse.map { |entry| entry.id.to_s }, items.map { |item| item["data-comment-id"] }
    end
    assert_select "section[data-comments] a[href=?]", root_path(anchor: "comments"), text: "Newer"
    assert_select "section[data-comments] a", text: "Older", count: 0
    assert_select "section[data-comments]", text: /Game-only comment/, count: 0
    assert_select "section[data-comments] form[action=?]", comments_path(page: 2)
  end

  test "game comments page only through that game's comments" do
    game = Game.create!(cfbd_id: 95_011)
    other = Game.create!(cfbd_id: 95_012)
    comments = 26.times.map { |i| Comment.create!(user: users(:one), game: game, body: "Game #{i}") }
    Comment.create!(user: users(:one), game: other, body: "Other game comment")
    Comment.create!(user: users(:one), body: "General comment")
    sign_in_as users(:one)

    get game_path(game)
    assert_select "section[data-comments] [data-comment-id]" do |items|
      assert_equal comments.last(25).reverse.map { |entry| entry.id.to_s }, items.map { |item| item["data-comment-id"] }
    end
    assert_select "section[data-comments] a[href=?]", game_path(game, page: 2, anchor: "comments"), text: "Older"
    assert_select "section[data-comments] a", text: "Newer", count: 0

    get game_path(game, page: 2)
    assert_empty comment_stream_names
    assert_select "section[data-comments] [data-comment-id]" do |items|
      assert_equal [ comments.first.id.to_s ], items.map { |item| item["data-comment-id"] }
    end
    assert_select "section[data-comments] a[href=?]", game_path(game, anchor: "comments"), text: "Newer"
    assert_select "section[data-comments] a", text: "Older", count: 0
    assert_select "section[data-comments]", text: /Other game comment|General comment/, count: 0
    assert_select "section[data-comments] form[action=?]", game_comments_path(game, page: 2)
  end

  test "out-of-range game comment pages show the last page of that game" do
    game = Game.create!(cfbd_id: 95_013)
    other = Game.create!(cfbd_id: 95_014)
    comments = 26.times.map { |i| Comment.create!(user: users(:one), game: game, body: "Game #{i}") }
    26.times { |i| Comment.create!(user: users(:two), game: other, body: "Other #{i}") }
    sign_in_as users(:one)

    get game_path(game, page: 100)

    assert_response :success
    assert_select "section[data-comments] [data-comment-id]" do |items|
      assert_equal [comments.first.id.to_s], items.map { |item| item["data-comment-id"] }
    end
    assert_select "section[data-comments]", text: /No comments yet/, count: 0
    assert_select "section[data-comments] a[href=?]", game_path(game, anchor: "comments"), text: "Newer"
    assert_select "section[data-comments] a", text: "Older", count: 0
    assert_select "section[data-comments]", text: /Other \d+/, count: 0
  end

  test "guests cannot post general or game comments" do
    game = Game.create!(cfbd_id: 95_007)

    assert_no_difference "Comment.count" do
      post comments_path, params: { comment: { body: "Nope" } }
      assert_redirected_to new_session_path
      post game_comments_path(game), params: { comment: { body: "Nope" } }
      assert_redirected_to new_session_path
    end
  end

  private

  def image_blob(type, size)
    header = type == "image/gif" ? "GIF89a" : "\x89PNG\r\n\x1a\n".b
    bytes = header + ("\0" * (size - header.bytesize))
    blob = ActiveStorage::Blob.create_before_direct_upload!(
      filename: "picture.#{type == "image/gif" ? "gif" : "png"}",
      content_type: type, byte_size: size,
      checksum: Base64.strict_encode64(Digest::MD5.digest(bytes))
    )
    blob.service.upload(blob.key, StringIO.new(bytes), checksum: blob.checksum)
    blob
  end

  def comment_stream_names
    css_select("section[data-comments] turbo-cable-stream-source").map do |source|
      Turbo.signed_stream_verifier.verified(source["signed-stream-name"])
    end
  end
end
