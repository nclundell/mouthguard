class Pick < ApplicationRecord
  belongs_to :game
  belongs_to :user
  belongs_to :team, optional: true

  validate :team_plays_in_game

  scope :correct, -> { where(correct: true) }
  scope :locked, -> { joins(:game).merge(Game.locked) }
  scope :open, -> { joins(:game).merge(Game.open) }

  def locked?
    game.locked?
  end

  def open?
    game.open?
  end

  private

  def team_plays_in_game
    return if team_id.nil? || game.nil?
    return if [ game.home_id, game.away_id ].compact.include?(team_id)

    errors.add(:team, "must be playing in the game")
  end
end
