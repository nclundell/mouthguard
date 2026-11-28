class GamesController < ApplicationController
  include CommentsPagination
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
    if params[:older_before].present?
      load_older_comments
      return render partial: "shared/comments_feed", layout: false,
        locals: { comments: @comments, page: params[:page].to_i.clamp(2, 10_000),
                  has_older_comments: @has_older_comments, page_path: game_path(@game), chat: true, game_chat: true }
    end

    load_comments(@game.comments.current)
    @comment = Comment.new
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

  private

  def load_older_comments
    scope = @game.comments.current
    anchor = scope.find_by(id: params[:older_before])
    if anchor
      entries = scope.includes(:user, :rich_text_body)
        .where("comments.created_at < :time OR (comments.created_at = :time AND comments.id < :id)",
          time: anchor.created_at, id: anchor.id)
        .order(created_at: :desc, id: :desc).limit(26).to_a
      @has_older_comments = entries.size > 25
      @comments = entries.first(25).reverse
    else
      @has_older_comments = false
      @comments = []
    end
  end
end
