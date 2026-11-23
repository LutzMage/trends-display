# Session handling for every controller (SPEC-002 §4).
# Protect an action with `before_action :require_authentication`.
module Authentication
  extend ActiveSupport::Concern

  SESSION_COOKIE = :td_session

  private

  def current_user
    return @current_user if defined?(@current_user)

    claims = session_claims
    @current_user = claims && User.find_by(id: claims["sub"])
  end

  def require_authentication
    render json: { error: "Not authenticated" }, status: :unauthorized unless current_user
  end

  def start_session(user)
    cookies[SESSION_COOKIE] = {
      value: SessionToken.issue(user),
      httponly: true,
      secure: true,
      same_site: :strict,
      path: "/",
      max_age: SessionToken::TTL.to_i
    }
    @current_user = user
  end

  def end_session
    claims = session_claims
    RevokedToken.revoke!(claims) if claims
    cookies.delete(SESSION_COOKIE, path: "/", httponly: true, secure: true, same_site: :strict)
    @current_user = nil
  end

  # Claims of a valid, unrevoked session token, or nil.
  def session_claims
    claims = SessionToken.decode(cookies[SESSION_COOKIE])
    claims unless claims.nil? || RevokedToken.revoked?(claims["jti"])
  end
end
