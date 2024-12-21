class Game < ApplicationRecord
  belongs_to :venue
  belongs_to :home, class_name: "Team"
  belongs_to :away, class_name: "Team"
end
