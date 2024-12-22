class Game < ApplicationRecord
  belongs_to :venue
  belongs_to :home, class_name: "Team"
  belongs_to :away, class_name: "Team"

  def is_live?
    return false if completed
    Time.now > start
  end
end
