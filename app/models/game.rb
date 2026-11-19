class Game < ApplicationRecord
  belongs_to :venue, optional: true
  belongs_to :home, class_name: "Team", optional: true
  belongs_to :away, class_name: "Team", optional: true
  has_many :picks, dependent: :destroy
end
