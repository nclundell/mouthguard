require "test_helper"

class CommentsHelperTest < ActionView::TestCase
  test "comma-separated raw image URLs each render without losing surrounding punctuation" do
    first = "https://example.com/a.png"
    second = "https://example.org/b.gif"
    fragment = render_body("<p>See #{first},#{second}! Done.</p>")

    node = fragment.at_css("p")
    assert_equal [ first, second ], node.css("img.comment-attachment-image").map { |image| image["src"] }
    assert_equal "See #{first},#{second}! Done.",
      node.children.map { |child| child.name == "img" ? child["src"] : child.text }.join
  end

  test "commas inside an image URL query are retained" do
    url = "https://example.com/a.png?size=wide,large"
    fragment = render_body("<p>#{url}, next</p>")

    assert_equal url, fragment.at_css("img.comment-attachment-image")["src"]
    assert_equal ", next", fragment.at_css("p").children.last.text
  end

  test "raw unsafe and non-image URLs stay text and URL-like substrings are not converted" do
    body = <<~HTML
      <p>http://example.com/a.gif https://user@example.com/a.gif
      https://example.com/gallery https://example.com/a.svg
      https://example.com/download?file=a.png
      prefixhttps://example.com/a.gif https://example.com/a.gifmore</p>
    HTML

    fragment = render_body(body)

    assert_empty fragment.css("img.comment-attachment-image")
    assert_includes fragment.text, "prefixhttps://example.com/a.gif"
  end

  test "direct image links retain their anchor and alt text without showing link text" do
    body = <<~HTML
      <p><a href="https://example.com/photo.gif">Photo label</a>
      <a href="https://example.com/gallery">https://example.com/photo.png</a>
      <code>https://example.com/code.jpg</code></p>
      <pre>https://example.com/pre.webp</pre>
    HTML

    fragment = render_body(body)

    assert_equal 1, fragment.css("img.comment-attachment-image").size
    link = fragment.css("a").first
    assert_equal "https://example.com/photo.gif", link["href"]
    assert_equal "https://example.com/photo.gif", link.at_css("img.comment-attachment-image")["src"]
    assert_equal "Photo label", link.at_css("img")["alt"]
    assert_empty link.text.strip
    assert_equal "https://example.com/photo.png", fragment.css("a").last.text
    assert_empty fragment.css("code img, pre img")
  end

  test "raw image URL becomes an image without leaving URL text" do
    url = "https://example.com/photo.png"
    fragment = render_body("<p>See #{url} now.</p>")

    assert_equal url, fragment.at_css("p > img.comment-attachment-image")["src"]
    assert_equal "See  now.", fragment.at_css("p").text
  end

  private

  def render_body(body)
    comment = Comment.new(user: users(:one), body: body)
    Nokogiri::HTML.fragment(comment_body_with_images(comment))
  end
end
