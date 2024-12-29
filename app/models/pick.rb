class Pick < ApplicationRecord
  belongs_to :game
  belongs_to :user
  belongs_to :team, optional: :true
end
