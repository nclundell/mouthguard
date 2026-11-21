require "test_helper"

class LegendsJobTest < ActiveSupport::TestCase
  test "loads the legacy winners and updates existing seasons without duplicates" do
    existing = Legend.create!(season: 2010, name: "Old winner")

    assert_difference("Legend.count", LegendsJob::WINNERS.size - 1) { LegendsJob.perform_now }
    assert_equal LegendsJob::WINNERS, Legend.order(:season).pluck(:season, :name).to_h
    assert_equal existing.id, Legend.find_by!(season: 2010).id

    assert_no_difference("Legend.count") { LegendsJob.perform_now }
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

    LegendsJob.perform_now

    assert_equal nathan, Legend.find_by!(season: 2009).user
    assert_nil Legend.find_by!(season: 2021).user
    assert_nil Legend.find_by!(season: 2019).user
    assert_not_equal other, Legend.find_by!(season: 2017).user

    nathan.update!(last_name: "Nelson")
    LegendsJob.perform_now
    assert_nil Legend.find_by!(season: 2009).user
  end
end
