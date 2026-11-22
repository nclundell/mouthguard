class Pick < ApplicationRecord
  belongs_to :game
  belongs_to :user
  belongs_to :team, optional: true

  validate :team_plays_in_game

  scope :open, -> {
    joins(:game)
    .where("games.season = ?", Current.season)
    .where("games.start IS NULL OR games.start > ?", Time.current)
  }

  def locked?
    game.start.present? && game.start <= Time.current
  end

  private

  def team_plays_in_game
    return if team_id.nil? || game.nil?
    return if [ game.home_id, game.away_id ].compact.include?(team_id)

    errors.add(:team, "must be playing in the game")
  end
end
