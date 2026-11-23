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

  private

  def post_params
    # No :user_id: the author is always the signed-in user (SPEC-002, AC-19).
    params.expect(post: [ :text, :media_type, :media_url ])
  end
end
