class Api::InteractionsController < ApplicationController
  include PostScoped

  # One-off events only. Like, save and comment have their own endpoints (SPEC-003 §5).
  RECORDABLE = %w[click share download].freeze

  before_action :require_authentication

  def create
    unless RECORDABLE.include?(params[:event_type])
      return render json: { errors: [ "Event type is not allowed" ] }, status: :unprocessable_entity
    end

    current_user.interactions.create!(post: current_post, event_type: params[:event_type])
    head :created
  end
end
