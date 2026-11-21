class Game < ApplicationRecord
  belongs_to :venue, optional: true
  belongs_to :home, class_name: "Team", optional: true
  belongs_to :away, class_name: "Team", optional: true
  has_many :picks, dependent: :destroy

  after_update_commit :broadcast_game, if: :saved_changes?

  scope :live, -> {
    where("start <= ?", Time.current)
    .where(completed: [ false, nil ])
    .where("status IS NULL OR status != ?", "completed")
  }

  def seed_picks
    User.find_each { |user| Pick.find_or_create_by(game: self, user: user) }
  end

  private

  def broadcast_game
    broadcast_replace_to "games", target: self, partial: "games/game_card", locals: { game: self }
  end
end
