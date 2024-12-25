class Game < ApplicationRecord
  belongs_to :venue
  belongs_to :home, class_name: "Team"
  belongs_to :away, class_name: "Team"

  has_many :game_comments
  has_many :picks

  def is_live?
    return false if completed
    Time.now > start
  end

  def today?
    start.to_date == Date.today
  end

  def winner
    return unless completed

    away_points > home_points ? away : home
  end
end
