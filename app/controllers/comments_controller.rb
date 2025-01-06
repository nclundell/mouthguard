class CommentsController < ApplicationController
  def create
  end

  private

  def comment_params
    params.require(:comment).permit(:user_id, :game_id, :season, :content)
  end
end
