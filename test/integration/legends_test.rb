require "test_helper"

class LegendsTest < ActionDispatch::IntegrationTest
  test "hall of fame groups wins by winner name and orders by wins then name" do
    user = users(:one)
    user.update!(display_name: "Captain Alex")
    user.avatar.attach(fixture_file_upload("avatar.svg", "image/svg+xml"))
    Legend.create!(name: "Alex", season: 2024)
    Legend.create!(name: "Alex", season: 2022, user: user)
    Legend.create!(name: "Zoe", season: 2023)
    Legend.create!(name: "Zoe", season: 2021)
    Legend.create!(name: "Bea", season: 2020)
    sign_in_as users(:two)

    get legends_path

    assert_response :success
    assert_select "main h1", text: "Legends", count: 1
    assert_select "main article", count: 3 do |cards|
      assert_equal [ "Captain Alex", "Zoe", "Bea" ], cards.map { |card| card.at_css("h2").text.strip }
      assert_equal [ "2", "2", "1" ], cards.map { |card| card.at_css("[data-wins]").text.strip }
      assert_equal [ "2022, 2024", "2021, 2023", "2020" ], cards.map { |card| card.at_css("[data-seasons]").text.strip }
    end
    assert_select "main article:first-of-type img[alt='Avatar for Captain Alex']", count: 1
    assert_select "main article:nth-of-type(2) svg[aria-hidden=true]", count: 2
    assert_select "main article svg[data-icon=mouthguard]", count: 0
    assert_select "main article", count: 3 do |cards|
      cards.each do |card|
        icons = card.at_css("[data-wins]").parent.css("svg")
        assert_equal [ "bacon-deodorant" ], icons.map { |icon| icon["data-icon"] }
        assert icons.all? { |icon| icon["aria-hidden"] == "true" }
        icon = icons.first
        assert_includes icon["class"].split, "size-9"
        assert_includes icon["class"].split, "text-amber-500"
        assert_equal "0 0 24 27.25", icon["viewBox"]
        assert_nil icon["width"]
        assert_nil icon["height"]
        assert_equal "currentColor", icon["stroke"]
        assert_equal "currentColor", icon.at_css("path[data-body]")["fill"]
        assert_equal "evenodd", icon.at_css("path[data-body]")["fill-rule"]
        assert_equal 4, icon.at_css("path[data-body]")["d"].scan(/[mM]/).length
        assert_empty icon.css("path[data-marbling]")
        assert_equal "butt", icon.at_css("path[data-outline]")["stroke-linecap"]
        assert_empty icon.css("[id], mask, text")
      end
    end
  end

  test "bacon deodorant asset leaves display size and color to the view" do
    assert_not File.exist?(Rails.root.join("app/assets/svg/icons/tabler/outline/bacon-deodorant.svg"))
    asset = Nokogiri::XML(File.read(Rails.root.join("app/assets/svg/icons/custom/bacon-deodorant.svg"))) { |config| config.strict }
    svg = asset.root

    assert_equal "0 0 24 27.25", svg["viewBox"]
    assert_nil svg["width"]
    assert_nil svg["height"]
    assert_nil svg["class"]
    assert_equal "currentColor", svg["stroke"]
    assert_equal "none", svg["fill"]
    assert_equal "currentColor", svg.at_xpath("./*[local-name()='path' and @data-body]")["fill"]
    body = svg.at_xpath("./*[local-name()='path' and @data-body]")
    outline = svg.at_xpath("./*[local-name()='path' and @data-outline]")
    assert_equal "none", outline["fill"]
    assert_equal "M5.5 26.55V7h13v19.55", outline["d"]
    assert_equal "butt", outline["stroke-linecap"]
    assert_empty svg.xpath("./*[local-name()='rect']")
    assert_equal "currentColor", body["fill"]
    assert_equal "evenodd", body["fill-rule"]
    assert_equal "none", body["stroke"]
    assert_match(/\AM5\.5 7H18\.5V26\.55H16\.1V22\.5/, body["d"])
    assert_equal 4, body["d"].scan(/v-4\.05/).length
    assert_equal 5, body["d"].scan(/v4\.05/).length
    silhouette, letter, upper_counter, lower_counter = body["d"].split("Z M")
    assert silhouette.end_with?("H5.5")
    assert_match(/\A8\.6 9\.55H12\.25C.*15\.5 16\.65C.*12\.3 19\.45H8\.6/, letter)
    assert_match(/\A10\.35 11\.15H12\.1C.*12\.1 13\.35H10\.35/, upper_counter)
    assert_match(/\A10\.35 15\.15H12\.25C.*12\.25 17\.85H10\.35/, lower_counter)
    assert_equal 4, body["d"].scan(/[mM]/).length
    assert_equal 4, body["d"].scan(/[zZ]/).length
    assert_empty svg.xpath("./*[local-name()='path' and @data-marbling]")
    assert_operator 5.5 - svg["stroke-width"].to_f / 2, :>, 0
    assert_operator 18.5 + svg["stroke-width"].to_f / 2, :<, 24
    assert_operator 26.55, :<, 27.25
    assert_equal 3, svg.xpath("./*[local-name()='path']").size
    assert_empty svg.xpath(".//@id | .//@mask")
    refute_match(/#[0-9a-fA-F]{3,8}\b|\b(?:white|black|amber)\b/, asset.to_xml)
  end

  test "missing user details and seasons render safely" do
    user = users(:one)
    Legend.create!(name: "Dana", user: user)
    Legend.create!(name: nil)
    sign_in_as users(:two)

    get legends_path

    assert_response :success
    assert_select "main article h2", text: "Dana"
    assert_select "main article h2", text: "Unknown winner"
    assert_select "main article img", count: 0
  end

  test "empty hall of fame has a helpful message" do
    sign_in_as users(:one)

    get legends_path

    assert_response :success
    assert_select "main h1", text: "Legends"
    assert_select "main article", count: 0
    assert_select "main", text: /No champions yet/
  end
end
