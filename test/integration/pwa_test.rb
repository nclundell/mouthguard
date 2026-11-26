require "test_helper"

class PwaTest < ActionDispatch::IntegrationTest
  test "pages link to the installable manifest" do
    get root_path

    assert_response :success
    assert_select 'link[rel="manifest"][href="/manifest.json"]', count: 1
  end

  test "manifest describes the app and its existing icon" do
    get "/manifest.json"

    assert_response :success
    assert_equal "application/json", response.media_type
    manifest = JSON.parse(response.body)
    assert_equal "Mouthguard", manifest.fetch("name")
    assert_equal "/", manifest.fetch("start_url")
    assert_equal "/", manifest.fetch("scope")
    assert_equal "standalone", manifest.fetch("display")
    assert_equal "#fffbeb", manifest.fetch("background_color")
    assert_equal "#171717", manifest.fetch("theme_color")
    assert_equal [ { "src" => "/icon.png", "type" => "image/png", "sizes" => "512x512" } ], manifest.fetch("icons")
  end

  test "root-scoped service worker is served as JavaScript without caching" do
    get "/service-worker"

    assert_response :success
    assert_match %r{(?:text|application)/javascript}, response.media_type
    assert_no_match(/(?:fetch|install|activate)\s*["']|caches\./, response.body)
  end
end
