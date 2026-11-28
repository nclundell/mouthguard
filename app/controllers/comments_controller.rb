class CommentsController < ApplicationController
  include CommentsPagination

  def create
    game = Game.find(params[:game_id]) if params[:game_id]
    comment = Current.user.comments.build(comment_params)
    comment.game = game
    destination = game ? game_path(game) : threads_path

    if comment.save
      redirect_to destination, notice: "Comment posted."
    else
      respond_to do |format|
        format.turbo_stream do
          load_comments(game ? game.comments.current : Comment.current.where(game_id: nil))
          render turbo_stream: turbo_stream.replace("comments", partial: "shared/comments",
             locals: { comments: @comments.reverse, threads: game.nil?, game_chat: game.present?, comment: comment, form_url: game ? game_comments_path(game, page: (@comment_page if @comment_page > 1)) : comments_path(page: (@comment_page if @comment_page > 1)),
                      page_path: destination, page: @comment_page, has_older_comments: @has_older_comments,
                      stream_name: game ? "game_comments_#{game.id}" : "threads_comments" }),
            status: :unprocessable_entity
        end
        format.html { redirect_to destination, alert: comment.errors.full_messages.to_sentence }
      end
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:body)
  end
end
