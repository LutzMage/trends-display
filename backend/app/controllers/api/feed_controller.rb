class Api::FeedController < ApplicationController
  DEFAULT_LIMIT = 20
  MAX_LIMIT = 50

  # GET /api/feed?user_id=1&cursor=...&limit=20
  def index
    user  = User.find(params[:user_id]) if params[:user_id].present? # temporary until auth
    limit = params.fetch(:limit, DEFAULT_LIMIT).to_i.clamp(1, MAX_LIMIT)

    render json: FeedQuery.new(user:, cursor: params[:cursor], limit:).call
  end
end
