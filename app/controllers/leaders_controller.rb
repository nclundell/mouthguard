class LeadersController < ApplicationController
  def index
    @leaders = User.rank
  end
end
