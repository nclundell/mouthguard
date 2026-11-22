class MyPicksController < ApplicationController
  def index
    Current.user.seed_picks

    @picks = Current.user.full_picks
  end

  def update
    pick = Current.user.picks.open.find(params[:id])

    if pick.update(team_id: params[:team_id])
      redirect_to my_picks_path
    else
      head :unprocessable_entity
    end
  end
end
