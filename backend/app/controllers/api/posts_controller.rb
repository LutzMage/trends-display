class Api::PostsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :post_not_found

  def create
    @post = Post.new(post_params)

    if @post.save
      render json: @post, status: :created
    else
      render json: { errors: @post.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    render json: Post.includes(:user).find(params[:id]).feed_json
  end

  private

  def post_not_found
    render json: { error: "Post not found" }, status: :not_found
  end

  def post_params
    params.expect(post: [ :user_id, :text, :media_type, :media_url ])
  end
end
