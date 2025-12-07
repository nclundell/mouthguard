include ApplicationHelper

class Users::PicksController < ApplicationController
  def index
    @user = User.find(params[:user_id])
    @available = Pick.for_user(@user).for_season.select { |p| p unless p.reveal? }
    @locked = Pick.for_user(@user).for_season.select { |p| p if p.reveal? }
  end

  def edit
    @user = User.find(params[:user_id])
    @available = Pick.for_user(@user).for_season.select { |p| p unless p.reveal? }
    @locked = Pick.for_user(@user).for_season.select { |p| p if p.reveal? }
  end

  def update
    users_picks_params.each do |upp|
      p = Pick.find_or_create_by(game_id: upp[:game_id], user_id: upp[:user_id])
      if p.user == Current.user
        p.update!(team_id: upp[:team_id])
      end
    end
    redirect_to user_picks_path(Current.user), notice: "Picks saved successfully!"
  end

  private

  def users_picks_params
    params[:user][:picks_attributes].values.map do |pa|
      pa.permit(:id, :game_id, :team_id, :user_id).to_h
    end
  end
end
