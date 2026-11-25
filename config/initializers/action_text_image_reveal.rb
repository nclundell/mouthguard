ActionText::ContentHelper.allowed_tags =
  Rails::HTML4::Sanitizer.safe_list_sanitizer.allowed_tags + [ ActionText::Attachment.tag_name, "figure", "figcaption", "button" ]
ActionText::ContentHelper.allowed_attributes =
  Rails::HTML4::Sanitizer.safe_list_sanitizer.allowed_attributes +
    ActionText::Attachment::ATTRIBUTES +
    %w[ type data-controller data-reveal-image-url-value data-reveal-image-alt-value ]
