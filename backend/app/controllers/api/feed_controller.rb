class Api::FeedController < ApplicationController
  DEFAULT_LIMIT = 20
  MAX_LIMIT = 50

  # GET /api/feed?cursor=...&limit=20
  # Ranked for the signed-in user (session cookie); newest first for anonymous visitors.
  def index
    limit = params.fetch(:limit, DEFAULT_LIMIT).to_i.clamp(1, MAX_LIMIT)

    render json: FeedQuery.new(user: current_user, cursor: params[:cursor], limit:).call
  end
end
