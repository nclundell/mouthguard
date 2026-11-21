class GamesController < ApplicationController
  def index
    @games = Game.where(season: Current.season).includes(:home, :away).order(:start)
  end

  def show
    @game = Game.find(params[:id])
  end
end
