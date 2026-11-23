class GamesController < ApplicationController
  def index
    @games = Game.where(season: Current.season).includes(:home, :away).order(:start).to_a
    @bowl_titles = @games.map { |game| game.notes.presence || "Game" }.uniq
    @teams = @games.flat_map { |game| [ game.home, game.away ] }.compact.uniq(&:id)
      .sort_by { |team| [ team.school.to_s.downcase, team.id ] }
    @conferences = @teams.filter_map { |team| team.conference.presence }.uniq.sort_by(&:downcase)
    school_counts = @teams.map { |team| team.school.presence || "Team" }.tally
    @team_labels = @teams.to_h do |team|
      school = team.school.presence || "Team"
      [ team.id, school_counts[school] > 1 ? "#{school} (#{team.id})" : school ]
    end
  end

  def show
    @game = Game.find(params[:id])
    @picks_visible = @game.locked?
    return unless @picks_visible

    @pick_names_by_side = { away: [], home: [] }
    @game.picks.includes(:user).order(:id).each do |pick|
      side = if pick.team_id == @game.away_id && @game.away_id.present?
               :away
             elsif pick.team_id == @game.home_id && @game.home_id.present?
               :home
             end
      @pick_names_by_side[side] << (pick.user&.name.presence || "Player") if side && pick.user
    end
  end
end
