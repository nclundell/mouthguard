class GamesController < ApplicationController
  def index
    @games = Game.this_season
  end

  def show
    @game = Game.find(params.expect(:id))
  end
end
