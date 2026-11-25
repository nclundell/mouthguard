class DashboardController < ApplicationController
  include CommentsPagination
  allow_unauthenticated_access

  def index
    if authenticated?
      load_comments(Comment.current.where(game_id: nil))
      @comment = Comment.new
    end

    now = Time.current
    @games = Game.current.includes(:home, :away).to_a.sort_by { |game| [ game.start.nil? ? 1 : 0, game.start || 0, game.id ] }
    @featured_game = @games.find { |game| !game.completed? && game.status != "completed" && game.start && game.start <= now } ||
                     @games.find { |game| !game.completed? && game.status != "completed" } ||
                     @games.reverse.find { |game| game.start && (game.completed? || game.status == "completed") } ||
                     @games.reverse.find { |game| game.completed? || game.status == "completed" }
    @scoreboard_context = if @featured_game&.completed? || @featured_game&.status == "completed"
                            "Latest results"
                          elsif @featured_game&.start && @featured_game.start <= now
                            "Live now · following the first kickoff"
                          else
                            "Next up · your bowl season at a glance"
                          end
  end
end
