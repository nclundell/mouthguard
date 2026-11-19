require "test_helper"
require_relative "../db/seeders/teams"
require "ostruct"

class TeamsSeederTest < ActiveSupport::TestCase
  test "maps CFBD teams and updates existing records when run again" do
    team = OpenStruct.new(
      id: 42,
      school: "Example State",
      mascot: "Falcons",
      abbreviation: "EXST",
      alternateNames: [ "Example" ],
      conference: "Atlantic",
      color: "#123456",
      alternateColor: "#abcdef",
      logos: [ "https://example.com/logo.png" ]
    )
    with_rest_teams([ team ]) do
      assert_difference("Team.count", 1) { TeamsSeeder.seed! }

      saved = Team.find_by!(cfbd_id: 42)
      assert_equal "Example State", saved.school
      assert_equal "Falcons", saved.mascot
      assert_equal "EXST", saved.abbreviation
      assert_equal [ "Example" ], saved.alternate_names
      assert_equal "Atlantic", saved.conference
      assert_equal "#123456", saved.color
      assert_equal "#abcdef", saved.alternate_color
      assert_equal [ "https://example.com/logo.png" ], saved.logos

      team.school = "Renamed State"
      team.alternateNames = [ "Renamed" ]
      assert_no_difference("Team.count") { TeamsSeeder.seed! }
      assert_equal saved.id, Team.find_by!(cfbd_id: 42).id
      assert_equal "Renamed State", saved.reload.school
      assert_equal [ "Renamed" ], saved.alternate_names
    end
  end

  test "rejects a team without a CFBD ID without inserting a row" do
    with_rest_teams([ OpenStruct.new(school: "Unknown State") ]) do
      assert_no_difference("Team.count") do
        error = assert_raises(ActiveRecord::NotNullViolation) { TeamsSeeder.seed! }
        assert_match(/cfbd_id/, error.message)
      end
    end
  end

  test "rolls back earlier inserts and updates when a later team lacks a CFBD ID" do
    existing = Team.create!(cfbd_id: 41, school: "Original State")
    sources = [
      OpenStruct.new(id: 41, school: "Renamed State"),
      OpenStruct.new(id: 42, school: "New State"),
      OpenStruct.new(school: "Unknown State")
    ]
    with_rest_teams(sources) do
      assert_no_difference("Team.count") do
        error = assert_raises(ActiveRecord::NotNullViolation) { TeamsSeeder.seed! }
        assert_match(/cfbd_id/, error.message)
      end
    end

    assert_nil Team.find_by(cfbd_id: 42)
    assert_equal "Original State", existing.reload.school
  end

  private

  def with_rest_teams(teams)
    original = Cfbd::Rest.method(:teams)
    Cfbd::Rest.define_singleton_method(:teams) { teams }
    yield
  ensure
    Cfbd::Rest.define_singleton_method(:teams, original)
  end
end
