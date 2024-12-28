include ApplicationHelper

class PicksController < ApplicationController
  def index
    @games = Game.where(season: current_season)
    @users = User.all
  end
end
