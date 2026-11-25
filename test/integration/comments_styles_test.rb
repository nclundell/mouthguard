require "test_helper"

class CommentsStylesTest < ActiveSupport::TestCase
  test "Lexxy dark colors are confined to the comments section" do
    css = Rails.root.join("app/assets/stylesheets/application.css").read
    declarations = css.match(/:is\(:root\[data-theme="dark"\], :root\.dark\) section\[data-comments\] \{([^}]+)\}/)

    assert declarations, "Expected a comments-only dark theme rule"
    %w[canvas ink ink-medium ink-lighter ink-lightest ink-inverted accent-dark selected selected-hover code-token-comment code-token-property].each do |name|
      assert_match(/--lexxy-color-#{name}: #[0-9a-f]{6};/, declarations[1])
    end
    assert_includes declarations[1], "--lexxy-color-text: #f5f5f5;"
    assert_includes declarations[1], "--lexxy-color-text-subtle: #d4d4d4;"
  end
end
