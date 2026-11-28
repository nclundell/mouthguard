module CommentsHelper
  IMAGE_PATH = /\.(?:gif|png|jpe?g|webp)\z/i
  RAW_URL = /(?<![^\s(\[{"',.!?;)\]}])https:\/\/(?:(?![,.!?;)\]}]https:\/\/)[^\s<>"'])+/i
  TRAILING_PUNCTUATION = /[.,!?;:)\]}]+\z/

  def comment_body_with_images(comment)
    # Action Text renders and sanitizes the body before we add checked image URLs.
    fragment = Nokogiri::HTML.fragment(comment.body.to_s)
    fragment.css("a[href]").each do |link|
      url = link["href"]
      uri = image_uri(url)
      next unless uri

      image = image_node(fragment, url, link.text.strip.presence || File.basename(uri.path))
      link.children.remove
      link.add_child(image)
    end
    fragment.xpath(".//text()[not(ancestor::a or ancestor::code or ancestor::pre)]").each do |text_node|
      text = text_node.text
      cursor = 0
      text.to_enum(:scan, RAW_URL).each do
        match = Regexp.last_match
        url = match[0].sub(TRAILING_PUNCTUATION, "")
        uri = image_uri(url)
        next unless uri

        text_node.add_previous_sibling(Nokogiri::XML::Text.new(text[cursor...match.begin(0)], fragment))
        text_node.add_previous_sibling(image_node(fragment, url, File.basename(uri.path)))
        cursor = match.begin(0) + url.length
      end
      text_node.content = text[cursor..] if cursor.positive?
    end
    fragment.to_html.html_safe
  end

  private

  def image_uri(url)
    uri = URI.parse(url)
    uri if uri.scheme == "https" && uri.host.present? && uri.userinfo.nil? && uri.path.match?(IMAGE_PATH)
  rescue URI::InvalidURIError
    nil
  end

  def image_node(fragment, url, alt)
    image = Nokogiri::XML::Node.new("img", fragment)
    image["src"] = url
    image["alt"] = alt
    image["loading"] = "lazy"
    image["referrerpolicy"] = "no-referrer"
    image["class"] = "comment-attachment-image"
    image
  end
end
