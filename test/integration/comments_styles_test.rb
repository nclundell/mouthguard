require "test_helper"

class CommentsStylesTest < ActiveSupport::TestCase
  test "Threads and game chat composers use two Lexxy rows on desktop and one on mobile without changing other composers" do
    css = Rails.root.join("app/assets/stylesheets/application.css").read

    desktop = css.split("@media (max-width: 639px)", 2).first
    mobile = css.match(/@media \(max-width: 639px\) \{(.*?)\n\}/m)

    assert_match(/section:is\(\.threads-comments, \.game-chat\) lexxy-editor\.comment-composer \{\s*--lexxy-editor-rows: 2lh;\s*\}/, desktop)
    assert mobile, "Expected mobile-only comment composer rules"
    assert_match(/section\.threads-comments lexxy-editor\.comment-composer \{\s*--lexxy-editor-rows: 1lh;\s*\}/, mobile[1])
    assert_match(/section\.game-chat lexxy-editor\.comment-composer \{\s*--lexxy-editor-rows: 1lh;\s*\}/, mobile[1])
    assert_no_match(/section\[data-comments\] lexxy-editor\.comment-composer/, css)
  end

  test "comment composer leaves the Lexxy toolbar unmodified on mobile" do
    css = Rails.root.join("app/assets/stylesheets/application.css").read
    mobile_rules = css.match(/@media \(max-width: 639px\) \{(.*?)\n\}/m)

    assert mobile_rules, "Expected mobile-only comment composer rules"
    assert_match(/section\.threads-comments lexxy-editor\.comment-composer \{\s*--lexxy-editor-rows: 1lh;\s*\}/, mobile_rules[1])
    assert_match(/section\.game-chat lexxy-editor\.comment-composer \{\s*--lexxy-editor-rows: 1lh;\s*\}/, mobile_rules[1])
    assert_no_match(/lexxy-toolbar|data-command=/, css)
  end

  test "short mobile Threads viewports return to document scrolling so the composer is reachable" do
    css = Rails.root.join("app/assets/stylesheets/application.css").read
    short_viewport = css.match(/@media \(max-width: 639px\) and \(max-height: 700px\) \{(.*?)\n\}/m)

    assert short_viewport, "Expected a short mobile viewport fallback"
    rules = short_viewport[1]
    assert_match(/body\.threads-layout \{[^}]*height: auto;[^}]*overflow: visible;[^}]*display: block;/m, rules)
    assert_match(/body\.threads-layout > main \{[^}]*flex: none;[^}]*display: block;/m, rules)
    assert_match(/body\.threads-layout section\.threads-comments \{[^}]*flex: none;[^}]*display: block;[^}]*overflow: visible;/m, rules)
    assert_match(/body\.threads-layout section\.threads-comments \.threads-feed \{[^}]*flex: none;[^}]*overflow-y: visible;/m, rules)
    assert_no_match(/scrollbar-width:\s*none|::-webkit-scrollbar/, rules)
  end

  test "Threads order controller scrolls before paint and follows growing content only near the feed bottom" do
    js = Rails.root.join("app/javascript/controllers/threads_order_controller.js").read

    assert_includes js, "this.followLatest = this.pageValue === 1"
    assert_includes js, "const feedChanged = feed !== this.feed"
    assert_includes js, 'getComputedStyle(feed).overflowY !== "auto"'
    assert_includes js, "feed.scrollTop = this.followLatest ? feed.scrollHeight : oldScrollTop"
    assert_includes js, "this.feed.scrollHeight - this.feed.clientHeight - this.feed.scrollTop <= 80"
    assert_includes js, "this.feed?.removeEventListener(\"scroll\", this.onFeedScroll)"
    assert_no_match(/requestAnimationFrame/, js)
    assert_match(/this\.syncScroll\(feed, oldScrollTop\)/, js)
    assert_match(/new ResizeObserver/, js)
    assert_match(/this\.resizeObserver\.observe\(list\)/, js)
  end

  test "desktop Threads and game chat have tall internal feeds and bottom composers without sizing other pages" do
    css = Rails.root.join("app/assets/stylesheets/application.css").read
    desktop = css.match(/@media \(min-width: 640px\) \{(.*?)\n\}/m)

    assert desktop
    assert_match(/section:is\(\.threads-comments, \.game-chat\) \{[^}]*height: 70dvh;[^}]*display: flex;[^}]*flex-direction: column;/m, desktop[1])
    assert_match(/section:is\(\.threads-comments, \.game-chat\) \.threads-feed \{[^}]*flex: 1;[^}]*min-height: 0;[^}]*overflow-y: auto;/m, desktop[1])
    assert_match(/section:is\(\.threads-comments, \.game-chat\) \.threads-composer \{[^}]*flex: none;/m, desktop[1])
    assert_no_match(/body\.game-show-layout|body\.threads-layout|\[data-picks-layout\]/, desktop[1])
  end

  test "mobile Threads bounds the page and scrolls messages inside the rounded panel above its composer" do
    css = Rails.root.join("app/assets/stylesheets/application.css").read
    mobile = css.match(/@media \(max-width: 639px\) \{(.*?)\n\}/m)

    assert mobile, "Expected mobile-only Threads rules"
    assert_match(/body\.threads-layout \{[^}]*height: 100dvh;[^}]*overflow: hidden;[^}]*display: flex;[^}]*flex-direction: column;/m, mobile[1])
    assert_match(/body\.threads-layout > main \{[^}]*flex: 1;[^}]*min-height: 0;[^}]*display: flex;[^}]*flex-direction: column;/m, mobile[1])
    assert_match(/body\.threads-layout section\.threads-comments \{[^}]*flex: 1;[^}]*min-height: 0;[^}]*display: flex;[^}]*flex-direction: column;/m, mobile[1])
    assert_match(/body\.threads-layout section\.threads-comments \.threads-feed \{[^}]*flex: 1;[^}]*min-height: 0;[^}]*overflow-y: auto;/m, mobile[1])
    assert_match(/body\.threads-layout section\.threads-comments \.threads-feed \{[^}]*overflow-y: auto;[^}]*scrollbar-width: none;/m, mobile[1])
    assert_match(/body\.threads-layout section\.threads-comments \.threads-feed::-webkit-scrollbar \{\s*display: none;\s*\}/, mobile[1])
    assert_match(/body\.threads-layout section\.threads-comments \.threads-composer \{[^}]*flex: none;/m, mobile[1])
    assert_no_match(/section\.threads-comments \{[^}]*margin-bottom: calc\(11rem/m, mobile[1])
    assert_no_match(/section\.threads-comments \.threads-composer \{[^}]*position: fixed;/m, mobile[1])
    assert_includes mobile[1], "env(safe-area-inset-bottom, 0px)"
    assert_no_match(/flex-direction:\s*column-reverse/, css)
  end

  test "normal-height mobile game show scrolls when hero or composer exceeds the available chat space" do
    css = Rails.root.join("app/assets/stylesheets/application.css").read
    mobile = css.match(/@media \(max-width: 639px\) \{(.*?)\n\}/m)[1]
    short = css.match(/@media \(max-width: 639px\) and \(max-height: 700px\) \{(.*?)\n\}/m)[1]

    assert_match(/body\.game-show-layout \{[^}]*height: 100dvh;[^}]*overflow-y: auto;[^}]*display: flex;[^}]*flex-direction: column;/m, mobile)
    assert_match(/body\.game-show-layout > header \{[^}]*flex: none;/m, mobile)
    assert_match(/body\.game-show-layout > main \{[^}]*flex: 1;[^}]*min-height: 0;[^}]*overflow: visible;[^}]*display: flex;[^}]*flex-direction: column;[^}]*env\(safe-area-inset-bottom, 0px\)/m, mobile)
    assert_match(/body\.game-show-layout \[data-picks-layout\] \{[^}]*flex: 1;[^}]*min-height: 0;[^}]*display: flex;[^}]*flex-direction: column;[^}]*align-items: stretch;/m, mobile)
    assert_match(/body\.game-show-layout \[data-game-content\] \{[^}]*flex: 1;[^}]*min-height: 0;[^}]*display: flex;[^}]*flex-direction: column;/m, mobile)
    assert_match(/body\.game-show-layout \[data-game-content\] > section\[id\^="game_hero_"\] \{[^}]*flex: none;/m, mobile)
    panel = mobile.match(/body\.game-show-layout section\.game-chat \{([^}]*)\}/)[1]
    feed = mobile.match(/section\.game-chat \.threads-feed \{([^}]*)\}/)[1]
    assert_match(/flex: 1;[^}]*min-height: min-content;[^}]*display: flex;[^}]*flex-direction: column;[^}]*overflow: visible;/m, panel)
    assert_match(/flex: 1;[^}]*min-height: 0;[^}]*overflow-y: auto;[^}]*contain: size;/m, feed)
    assert_match(/section\.game-chat \.threads-feed \{[^}]*overflow-y: auto;[^}]*scrollbar-width: none;/m, mobile)
    assert_match(/section\.game-chat \.threads-feed::-webkit-scrollbar \{\s*display: none;/, mobile)
    assert_match(/section\.game-chat \.threads-composer \{[^}]*flex: none;/m, mobile)
    assert_match(/section\.game-chat \.threads-composer \{[^}]*order: 1;/m, mobile)
    assert_match(/body\.game-show-layout \{[^}]*height: auto;[^}]*overflow: visible;[^}]*display: block;/m, short)
    assert_match(/body\.game-show-layout > main \{[^}]*flex: none;[^}]*display: block;/m, short)
    assert_match(/body\.game-show-layout \[data-picks-layout\] \{[^}]*flex: none;[^}]*display: grid;/m, short)
    assert_match(/body\.game-show-layout \[data-game-content\] \{[^}]*flex: none;[^}]*display: block;/m, short)
    assert_match(/body\.game-show-layout section\.game-chat \{[^}]*flex: none;[^}]*display: block;[^}]*overflow: visible;/m, short)
    assert_match(/section\.game-chat \.threads-feed \{[^}]*flex: none;[^}]*overflow-y: visible;[^}]*contain: none;/m, short)
    assert_match(/:root\.threads-js body\.game-show-layout section\.game-chat \.threads-feed\[data-initial-scroll-pending\] \{[^}]*visibility: hidden;/m, css)
    assert_no_match(/body\.threads-layout/, Rails.root.join("app/views/games/show.html.erb").read)
    layout = Rails.root.join("app/views/layouts/application.html.erb").read
    assert_includes layout, "threads-layout' if controller_name == 'threads' && action_name == 'index'"
    assert_includes layout, "game-show-layout' if controller_name == 'games' && action_name == 'show'"
    comments = Rails.root.join("app/views/shared/_comments.html.erb").read
    assert_match(/class="mt-10 rounded-2xl border border-pine-600\/30 bg-white p-5 shadow-sm[^"]*<%= ' threads-comments' if local_assigns\[:threads\] %><%= ' game-chat' if local_assigns\[:game_chat\] %>"/, comments)
  end

  test "mobile game and Threads feeds and composers share scroll decoration and separator styling" do
    mobile = Rails.root.join("app/assets/stylesheets/application.css").read.match(/@media \(max-width: 639px\) \{(.*?)\n\}/m)[1]
    rule = ->(selector) { mobile.match(/#{Regexp.escape(selector)} \{([^}]*)\}/)[1].strip }

    threads_feed = rule.call("body.threads-layout section.threads-comments .threads-feed")
    game_feed = rule.call("section.game-chat .threads-feed")
    %w[overflow-y overflow-anchor overscroll-behavior scrollbar-width].each do |property|
      assert_equal threads_feed.match(/#{property}: ([^;]+);/)[1],
        game_feed.match(/#{property}: ([^;]+);/)[1]
    end
    assert_equal rule.call("body.threads-layout section.threads-comments .threads-feed::-webkit-scrollbar"),
      rule.call("section.game-chat .threads-feed::-webkit-scrollbar")
    %w[flex padding-top border-top].each do |property|
      assert_equal rule.call("body.threads-layout section.threads-comments .threads-composer").match(/#{property}: ([^;]+);/)[1],
        rule.call("section.game-chat .threads-composer").match(/#{property}: ([^;]+);/)[1]
    end
    css = Rails.root.join("app/assets/stylesheets/application.css").read
    assert_equal css.match(/section\.threads-comments \.threads-list \{([^}]*)\}/)[1],
      css.match(/section\.game-chat \.threads-list \{([^}]*)\}/)[1]
  end

  test "pending mobile page-one feed is hidden only with JS and reveals if modules fail" do
    css = Rails.root.join("app/assets/stylesheets/application.css").read

    assert_match(/@media \(max-width: 639px\) and \(min-height: 701px\) \{\s*:root\.threads-js body\.threads-layout \.threads-feed\[data-initial-scroll-pending\] \{[^}]*visibility: hidden;[^}]*animation: threads-feed-fallback 0s 2s forwards;/m, css)
    assert_match(/:root\.threads-js body\.game-show-layout section\.game-chat \.threads-feed\[data-initial-scroll-pending\] \{[^}]*visibility: hidden;[^}]*animation: threads-feed-fallback 0s 2s forwards;/m, css)
    assert_match(/@keyframes threads-feed-fallback \{\s*to \{ visibility: visible; \}/, css)
  end

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
