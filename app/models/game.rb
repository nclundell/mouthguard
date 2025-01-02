class Game < ApplicationRecord
  include Turbo::Broadcastable

  belongs_to :venue, optional: :true
  belongs_to :home, class_name: "Team"
  belongs_to :away, class_name: "Team"

  has_many :game_comments
  has_many :picks

  def is_live?
    return false if completed
    return false if away_line_scores.nil?
    return false if home_line_scores.nil?

    Time.now > start
  end

  def is_completed?
    return true if completed

    false
  end

  def today?
    adjusted_start = start - 5.hours # Default check in EST
    adjusted_start.to_date == Date.today
  end

  def winner
    return unless completed

    away_points > home_points ? away : home
  end
end
