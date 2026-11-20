# Signs and verifies the session JWT stored in the td_session cookie (SPEC-002 §4.1).
class SessionToken
  TTL = 24.hours
  ALGORITHM = "HS256"
  REQUIRED_CLAIMS = %w[sub jti exp].freeze

  def self.issue(user)
    now = Time.current.to_i
    payload = { sub: user.id.to_s, jti: SecureRandom.uuid, iat: now, exp: now + TTL.to_i }
    JWT.encode(payload, secret, ALGORITHM)
  end

  # Returns the claims, or nil for a missing, expired, tampered or malformed token.
  def self.decode(token)
    return if token.blank?

    claims, _header = JWT.decode(token, secret, true, algorithm: ALGORITHM, required_claims: REQUIRED_CLAIMS)
    claims
  rescue JWT::DecodeError
    nil
  end

  def self.secret
    ENV.fetch("JWT_SECRET")
  end
end
