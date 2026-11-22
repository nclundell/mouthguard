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
  end
end
