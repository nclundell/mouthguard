class ImageDirectUploadsController < ActiveStorage::DirectUploadsController
  def create
    blob = params.require(:blob)
    if blob[:content_type].to_s.start_with?("image/") && blob[:byte_size].to_i > CommentImagePolicy::MAXIMUM_SIZE
      render json: { error: "Images must be 25 MB or smaller." }, status: :unprocessable_entity
    else
      super
    end
  end
end
