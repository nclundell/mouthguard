require "test_helper"

class LegendTest < ActiveSupport::TestCase
  test "persists a legend without an associated user" do
    legend = Legend.create!(season: 2026, name: "Winner")

    legend.reload
    assert_equal 2026, legend.season
    assert_equal "Winner", legend.name
    assert_nil legend.user
  end
end
