class ThreadsController < ApplicationController
  include CommentsPagination

  def index
    if params[:older_before].present?
      load_older_comments
      return render partial: "shared/comments_feed", layout: false,
        locals: { comments: @comments.reverse, page: params[:page].to_i.clamp(2, 10_000),
                  has_older_comments: @has_older_comments, page_path: threads_path, chat: true }
    end

    @games = Game.current.includes(:home, :away).to_a.sort_by do |game|
      [ game.completed? || game.status == "completed" ? 1 : 0, game.start.nil? ? 1 : 0, game.start || 0, game.id ]
    end
    @game_comment_counts = Comment.current.where(game_id: @games.map(&:id)).group(:game_id).count
    load_comments(Comment.current.where(game_id: nil))
    @comment = Comment.new
  end

  private

  def load_older_comments
    scope = Comment.current.where(game_id: nil)
    anchor = scope.find_by(id: params[:older_before])
    if anchor
      entries = scope.includes(:user, :rich_text_body)
        .where("comments.created_at < :time OR (comments.created_at = :time AND comments.id < :id)",
          time: anchor.created_at, id: anchor.id)
        .order(created_at: :desc, id: :desc).limit(26).to_a
      @has_older_comments = entries.size > 25
      @comments = entries.first(25)
    else
      @has_older_comments = false
      @comments = []
    end
  end
end
