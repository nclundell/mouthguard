include ApplicationHelper

class Game < ApplicationRecord
  include Turbo::Broadcastable

  after_create :populate_picks
  after_save :update_picks_correctness, if: :saved_change_to_completed?

  belongs_to :venue, optional: :true
  belongs_to :home, class_name: "Team"
  belongs_to :away, class_name: "Team"

  has_many :comments, dependent: :destroy
  has_many :picks, dependent: :destroy

  scope :completed, -> { where(completed: true) }
  scope :incomplete, -> { where.not(completed: true) }
  scope :this_season, -> { where(season: current_season).order(:start) }
  scope :with_no_media, -> { where(tv: nil) }
  scope :live, -> {
    where(completed: false).
    where("start < ?", Time.now)
  }
  scope :to_be_played, -> {
    where(completed: false).
    where("start > ?", Time.now)
  }

  def reveal_picks?
    completed? || is_live?
  end

  def is_live?
    completed ? false : Time.now > start
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

  def update_picks_correctness
    return unless completed

     picks.where(team: winner).update_all(correct: true)
     picks.where.not(team: winner).update_all(correct: false)
  end

  def populate_picks
    User.all.each { |u| Pick.find_or_create_by(user: u, game: self, season: season)}
  end

  def winner
    return unless completed

    @winner ||= away_points > home_points ? away : home
  end
end
