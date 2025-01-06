include ApplicationHelper

class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :game, optional: :true

  scope :for_season, ->(season = current_season) { where(season: season) }
end
