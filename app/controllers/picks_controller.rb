include ApplicationHelper

class PicksController < ApplicationController
  def index
    @games = Game.where(season: current_season).where(id: Pick.select(:game_id))
    @users = User.all
  end
end
