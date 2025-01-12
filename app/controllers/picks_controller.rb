include ApplicationHelper

class PicksController < ApplicationController
  def index
    @games = Game.where(season: current_season).where(id: Pick.select(:game_id))
    @users = User.where(id: Pick.select(:user_id)).sort_by { |user| user.name }
  end
end
