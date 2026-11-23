class LegendsController < ApplicationController
  def index
    @legends = Legend.hall_of_fame
  end
end
