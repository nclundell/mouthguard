class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :game, optional: true
  has_rich_text :body

  before_create :set_season
  after_create_commit :broadcast_comment

  validates :body, presence: true
  validate :attachment_only_images
  validate :image_attachments_within_limit

  scope :current, -> { where(season: Current.season) }

  private

  def set_season
    self.season = Current.season
  end

  def attachment_only_images
    return unless body.present?

    if Nokogiri::HTML.fragment(body.body.to_html).css("img, button").any?
      errors.add(:body, "images must be uploaded as attachments")
    end
  end

  def image_attachments_within_limit
    return unless body.present?

    body.embeds.each do |blob|
      actual_size = File.size(blob.service.path_for(blob.key))
      prefix = blob.download_chunk(0..8191)
      signature_type = Marcel::MimeType.for(StringIO.new(prefix))
      actual_image = signature_type.start_with?("image/") || prefix.match?(/\A\s*<svg(?:\s|>)/i)
      next unless actual_image || blob.image?

      if actual_size > CommentImagePolicy::MAXIMUM_SIZE
        errors.add(:body, "images must be 25 MB or smaller")
        next
      end

      blob.open do |file|
        actual_type = actual_image ? Marcel::MimeType.for(file, name: blob.filename.to_s) : signature_type
        actual_type = "image/svg+xml" if prefix.match?(/\A\s*<svg(?:\s|>)/i)

        if !actual_image || file.size != actual_size || actual_size != blob.byte_size || actual_type != blob.content_type
          errors.add(:body, "image upload metadata does not match the uploaded file")
        end
      end
    rescue ActiveStorage::FileNotFoundError, ActiveStorage::IntegrityError, Errno::ENOENT
      errors.add(:body, "attachment upload is missing or invalid")
    end
  end

  def broadcast_comment
    stream = game_id ? "game_comments_#{game_id}" : "threads_comments"
    scope = game_id ? Comment.current.where(game_id: game_id) : Comment.current.where(game_id: nil)
    entries = scope.includes(:user, :rich_text_body).order(created_at: :desc, id: :desc).limit(26).to_a
    broadcast_replace_to stream, target: "comments_feed", partial: "shared/comments_feed",
      locals: { comments: entries.first(25).reverse, chat: true, game_chat: game_id.present?, page: 1, has_older_comments: entries.size > 25,
                page_path: game_id ? Rails.application.routes.url_helpers.game_path(game_id) : Rails.application.routes.url_helpers.threads_path }
    if game_id
      broadcast_replace_to "threads_games", target: "threads_game_#{game_id}", partial: "threads/game_card",
        locals: { game: game, comment_count: game.comments.current.count }
    end
  end
end
