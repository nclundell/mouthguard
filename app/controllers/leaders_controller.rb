class LeadersController < ApplicationController
  def index
    @season = Current.season
    @leaders = UserRankingService.rank_users(season: @season)
  end
end
