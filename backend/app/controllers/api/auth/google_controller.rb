# Google sign-in through Auth0 (SPEC-002 §4.4). Both actions are full-page navigations, so they redirect.
class Api::Auth::GoogleController < ApplicationController
  OAUTH_COOKIE = :td_oauth
  OAUTH_COOKIE_PATH = "/api/auth/google" # also covers /callback
  OAUTH_TTL = 10.minutes

  # Missing Auth0 config, a rejected code or an invalid ID token: back to the login page.
  rescue_from Auth0Client::Error do |error|
    Rails.logger.warn("Google sign-in failed: #{error.message}")
    fail_with "google_failed"
  end

  def start
    state, nonce, verifier = Array.new(3) { SecureRandom.urlsafe_base64(32) }
    url = Auth0Client.authorize_url(state:, nonce:, code_challenge: pkce_challenge(verifier))

    # Lax, not Strict: the callback arrives as a navigation from Auth0, which is another site.
    cookies.encrypted[OAUTH_COOKIE] = {
      value: { state:, nonce:, verifier:, at: Time.current.to_i },
      httponly: true, secure: true, same_site: :lax, path: OAUTH_COOKIE_PATH, max_age: OAUTH_TTL.to_i
    }
    redirect_to url, allow_other_host: true
  end

  def callback
    oauth = cookies.encrypted[OAUTH_COOKIE]
    cookies.delete(OAUTH_COOKIE, path: OAUTH_COOKIE_PATH, httponly: true, secure: true, same_site: :lax)

    return fail_with("google_cancelled") if params[:error] == "access_denied"
    return fail_with("google_failed") if params[:error].present? || !valid_oauth_state?(oauth)

    claims = Auth0Client.exchange_code(code: params[:code].to_s, code_verifier: oauth["verifier"], nonce: oauth["nonce"])
    return fail_with("email_unverified") unless claims["email_verified"] == true

    user = User.find_by(email: claims["email"].to_s)
    return fail_with("no_account") unless user # user creation is out of scope (SPEC-002 §2.2)

    start_session(user)
    redirect_to "#{frontend_url}/", allow_other_host: true
  end

  private

  # The cookie must exist, be younger than OAUTH_TTL (checked here, not trusted to the browser),
  # and hold the same state Auth0 echoed back.
  def valid_oauth_state?(oauth)
    oauth.is_a?(Hash) &&
      oauth["at"].to_i > OAUTH_TTL.ago.to_i &&
      params[:state].present? &&
      ActiveSupport::SecurityUtils.secure_compare(oauth["state"].to_s, params[:state].to_s)
  end

  def pkce_challenge(verifier)
    Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
  end

  def fail_with(code)
    redirect_to "#{frontend_url}/login?error=#{code}", allow_other_host: true
  end

  def frontend_url
    Rails.application.config.x.frontend_url
  end
end
