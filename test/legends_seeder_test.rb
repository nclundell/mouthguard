require "test_helper"
require_relative "../db/seeders/legends"

class LegendsSeederTest < ActiveSupport::TestCase
  test "loads the legacy winners and updates existing seasons without duplicates" do
    existing = Legend.create!(season: 2010, name: "Old winner")

    assert_difference("Legend.count", 15) { LegendsSeeder.seed! }
    assert_equal LegendsSeeder::WINNERS, Legend.order(:season).pluck(:season, :name).to_h
    assert_equal existing.id, Legend.find_by!(season: 2010).id

    assert_no_difference("Legend.count") { LegendsSeeder.seed! }
    assert_equal "Karen Lundell", existing.reload.name
  end

  test "associates matching users and leaves unmatched winners without one" do
    nathan = User.create!(
      email_address: "nathan@example.com", password: "password",
      first_name: "Nathan", last_name: "Lundell"
    )
    other = User.create!(
      email_address: "other@example.com", password: "password",
      first_name: "Nathan", last_name: "Nelson"
    )

    LegendsSeeder.seed!

    assert_equal nathan, Legend.find_by!(season: 2009).user
    assert_nil Legend.find_by!(season: 2021).user
    assert_nil Legend.find_by!(season: 2019).user
    assert_not_equal other, Legend.find_by!(season: 2017).user

    nathan.update!(last_name: "Nelson")
    LegendsSeeder.seed!
    assert_nil Legend.find_by!(season: 2009).user
  end
end
