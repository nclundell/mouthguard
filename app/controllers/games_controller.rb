class GamesController < ApplicationController
  def index
    @games = Game.where(season: current_season)
  end

  def show
    @game = Game.find(params.expect(:id))
  end
end
