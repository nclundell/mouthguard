class PicksController < ApplicationController
  def index
    @games = Game.where(season: Rails.application.credentials.season)
    @users = User.all
  end
end
