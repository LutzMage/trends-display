class ApplicationController < ActionController::API
  include ActionController::Cookies
  include Authentication

  STATE_CHANGING_METHODS = %w[POST PUT PATCH DELETE].freeze

  # Runs before every other filter, so refused requests don't count towards the sign-in rate limit.
  before_action :reject_foreign_origin

  private

  # Defence in depth against CSRF (SPEC-002 §4.5): refuse state-changing requests that say they
  # come from another site. No Origin header (curl, tests) is allowed; "null" counts as foreign.
  def reject_foreign_origin
    return unless STATE_CHANGING_METHODS.include?(request.request_method)
    return if request.origin.blank? || request.origin == Rails.application.config.x.frontend_url

    render json: { error: "Forbidden origin" }, status: :forbidden
  end
end
