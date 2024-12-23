class GameComment < ApplicationRecord
  belongs_to :game
  belongs_to :user

  has_rich_text :comment
end
