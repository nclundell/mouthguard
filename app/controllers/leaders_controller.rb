include ApplicationHelper

class LeadersController < ApplicationController
  def index
    @leaders = User.rank
    @season = current_season
  end
end
