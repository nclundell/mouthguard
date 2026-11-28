module CommentsHelper
  IMAGE_PATH = /\.(?:gif|png|jpe?g|webp)\z/i

  def comment_body_with_images(comment)
    # Action Text renders and sanitizes the body before we add checked image URLs.
    fragment = Nokogiri::HTML.fragment(comment.body.to_s)
    fragment.css("a[href]").each do |link|
      url = link["href"]
      uri = URI.parse(url)
      next unless uri.scheme == "https" && uri.host.present? && uri.userinfo.nil? && uri.path.match?(IMAGE_PATH)

      image = Nokogiri::XML::Node.new("img", fragment)
      image["src"] = url
      image["alt"] = link.text.strip.presence || File.basename(uri.path)
      image["loading"] = "lazy"
      image["referrerpolicy"] = "no-referrer"
      image["class"] = "comment-attachment-image"
      link.add_next_sibling(image)
    rescue URI::InvalidURIError
      next
    end
    fragment.to_html.html_safe
  end
end
