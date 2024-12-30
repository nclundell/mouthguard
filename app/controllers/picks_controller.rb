include ApplicationHelper

class PicksController < ApplicationController
  def index
    @current_user = Current.user
    @games = Game.where(season: current_season)
    @users = User.all
  end
end
