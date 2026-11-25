module CommentsPagination
  private

  def load_comments(scope)
    @comment_page = [params[:page].to_i, 1].max
    if @comment_page > 1
      last_page = [(scope.count + 24) / 25, 1].max
      @comment_page = [@comment_page, last_page].min
    end
    entries = scope.includes(:user, :rich_text_body)
      .order(created_at: :desc, id: :desc)
      .offset((@comment_page - 1) * 25).limit(26).to_a
    @has_older_comments = entries.size > 25
    @comments = entries.first(25)
  end
end
