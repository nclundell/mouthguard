include ApplicationHelper

class Pick < ApplicationRecord
  belongs_to :game
  belongs_to :user
  belongs_to :team, optional: :true

  scope :picked, -> { where.not(team_id: nil) }
  scope :unpicked, -> { where(team_id: nil) }

  scope :for_game, ->(game) { where(game: game) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_season, ->(season = current_season) { where(season: season) }

  def reveal?
    game.completed? || game.is_live?
  end
end
