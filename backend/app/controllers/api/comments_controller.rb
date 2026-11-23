class Api::CommentsController < ApplicationController
  include PostScoped

  # shortcut: only the 100 newest, with no pagination; add a cursor (as the feed has) once posts get more comments.
  LIMIT = 100

  before_action :require_authentication, only: :create

  def index
    comments = current_post.comments.includes(:user).order(created_at: :desc, id: :desc).limit(LIMIT)
    render json: { comments: comments.map(&:api_json) }
  end

  def create
    comment = current_post.comments.new(comment_params.merge(user: current_user))

    if comment.save
      render json: comment.api_json, status: :created
    else
      render json: { errors: comment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def comment_params
    params.expect(comment: [ :body ])
  end
end
