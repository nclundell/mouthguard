include ApplicationHelper

class LeadersController < ApplicationController
  def index
    @leaders = UserRankingService.rank_users
    @season = current_season
  end
end
