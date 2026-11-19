require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  test "season is the year six months before today" do
    travel_to Time.zone.local(2026, 5, 15) do
      assert_equal 2025, Current.season
    end

    travel_to Time.zone.local(2026, 8, 15) do
      assert_equal 2026, Current.season
    end
  end
end
