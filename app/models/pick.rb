class Pick < ApplicationRecord
  belongs_to :game
  belongs_to :user
  belongs_to :team, optional: :true

  scope :not_picked, -> { where(team_id: nil) }
  scope :picked, -> { where.not(team_id: nil) }

  scope :by_game, ->(game) { where(game: game) }
  scope :by_user, ->(user) { where(user: user) }

  def reveal?
    game.completed? || game.is_live?
  end
end
