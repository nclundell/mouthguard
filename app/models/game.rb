class Game < ApplicationRecord
  belongs_to :venue, optional: true
  belongs_to :home, class_name: "Team", optional: true
  belongs_to :away, class_name: "Team", optional: true
  has_many :picks, dependent: :destroy

  after_update :update_pick_correctness
  after_update_commit :broadcast_game, if: :saved_changes?

  scope :current, -> { where(season: Current.season) }
  scope :live, -> {
    where("start <= ?", Time.current)
    .where(completed: [ false, nil ])
    .where("status IS NULL OR status != ?", "completed")
  }
  scope :locked, -> { where("start <= ?", Time.current) }
  scope :open, -> { where("start is null or start > ?", Time.current) }

  def open?
    start.nil? || start > Time.current
  end
  
  def locked?
    start.present? && start <= Time.current
  end

  def winner
    return unless completed? && !away_points.nil? && !home_points.nil?
    return if away_points == home_points

    away_points > home_points ? away : home
  end

  private

  def update_pick_correctness
    return unless winner

    picks.each do |pick|
      pick.correct = pick.team == winner ? true : false
      pick.save
    end
  end

  def broadcast_game
    broadcast_replace_to "games", target: self, partial: "games/game_card", locals: { game: self }
  end
end
