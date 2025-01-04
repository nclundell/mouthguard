class Game < ApplicationRecord
  include Turbo::Broadcastable

  belongs_to :venue, optional: :true
  belongs_to :home, class_name: "Team"
  belongs_to :away, class_name: "Team"

  has_many :game_comments
  has_many :picks, dependent: :destroy

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
    est_date = Time.now.localtime("-05:00").to_date
    est_start_date = start.to_time.localtime("-05:00").to_date

    est_date == est_start_date
  end

  def winner
    return unless completed

    away_points > home_points ? away : home
  end
end
