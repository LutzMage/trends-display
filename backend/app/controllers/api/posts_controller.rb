class Api::PostsController < ApplicationController
  def create
    @post = Post.new(post_params)

    if @post.save
      render json: @post, status: :created
    else
      render json: { errors: @post.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    render json: Post.find(params[:id]), status: :ok
  end

  private

  def post_params
    params.expect(post: [:user_id, :text, :media_type, :media_url])
  end
end
