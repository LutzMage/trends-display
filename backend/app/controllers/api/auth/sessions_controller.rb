# Email + password sign-in and sign-out (SPEC-002 §4.3, §4.6, §4.7).
class Api::Auth::SessionsController < ApplicationController
  # shortcut: per-process memory, so the limit resets on restart and is not shared; move to Solid Cache when deployed.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  # Sets a max of 10 attempts per 3 minutes. Slightly stricter than NIST SP 800-63B
  rate_limit to: 10, within: 3.minutes, only: :create, store: RATE_LIMIT_STORE,
    with: -> { render json: { error: "Too many attempts. Try again later." }, status: :too_many_requests }

  def create
    # authenticate_by hashes even when the email is unknown, so timing doesn't reveal which emails exist.
    user = User.authenticate_by(email: params[:email].to_s, password: params[:password].to_s)

    if user
      start_session(user)
      render json: user.account_json
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end

  def destroy
    end_session
    head :no_content
  end
end
