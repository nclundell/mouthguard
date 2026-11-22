class PicksController < ApplicationController
  def index
    @games = Game.current.includes(:away, :home).order(:start, :id).to_a
    @bowl_titles = @games.map { |game| game.notes.presence || "Game" }.uniq
    @locked_game_ids = @games.select(&:locked?).map(&:id)
    picks = Pick.where(game_id: @locked_game_ids).includes(:user, :team).order(:id).to_a
    @users = picks.map(&:user).uniq.sort_by { |user| [ (user.name.presence || "Player").downcase, user.id ] }
    @user_labels = @users.to_h { |user| [ user.id, user.name.presence || "Player" ] }
    requested_ids = params[:selected_user_ids].is_a?(Array) ? params[:selected_user_ids] : []
    @selected_user_ids = requested_ids & @users.map { |user| user.id.to_s }
    @visible_users = @selected_user_ids.empty? ?
      @users : @users.select { |user| @selected_user_ids.include?(user.id.to_s) }
    @picks_by_game = picks.group_by(&:game_id).transform_values { |game_picks| game_picks.index_by(&:user_id) }
  end
end
