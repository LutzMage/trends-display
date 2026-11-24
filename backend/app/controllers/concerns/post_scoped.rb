# The post named in the URL, for /api/posts/:id and the routes nested under it (/api/posts/:post_id/...).
module PostScoped
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :post_not_found
  end

  private

  # Lazy on purpose: require_authentication (a before_action) runs first, so anonymous callers get 401, not 404.
  def current_post
    @current_post ||= Post.find(params[:post_id] || params[:id])
  end

  def post_not_found
    render json: { error: "Post not found" }, status: :not_found
  end
end
