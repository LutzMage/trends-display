class Api::PostsController < ApplicationController
  include PostScoped

  before_action :require_authentication, only: :create

  def create
    @post = current_user.posts.new(post_params)

    if @post.save
      render json: @post, status: :created
    else
      render json: { errors: @post.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    render json: current_post.detail_json(current_user)
  end

  # The image as a file, fetched through ImageDownload's host allowlist (SPEC-003 §3.7, §5).
  def download
    return render json: { error: "Post has no image" }, status: :not_found unless current_post.image?

    image = ImageDownload.fetch(current_post.media_url)
    send_data image.body, type: image.content_type, disposition: "attachment",
      filename: "trends-post-#{current_post.id}.#{image.extension}"
  rescue ImageDownload::NotAllowed
    Rails.logger.info("Image download refused for post #{current_post.id}: host not in DOWNLOAD_HOSTS")
    render json: { error: "Download is not available for this image" }, status: :unprocessable_entity
  rescue ImageDownload::Unavailable => e
    Rails.logger.warn("Image download failed for post #{current_post.id}: #{e.message}")
    render json: { error: "Image unavailable" }, status: :bad_gateway
  end

  private

  def post_params
    # No :user_id: the author is always the signed-in user (SPEC-002, AC-19).
    params.expect(post: [ :text, :media_type, :media_url ])
  end
end
