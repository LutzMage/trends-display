require "net/http"
require "json"

# Google sign-in through Auth0: OIDC Authorization Code flow with PKCE (SPEC-002 §4.4).
# The browser never sees Auth0 tokens; callers get verified ID-token claims or an Error.
class Auth0Client
  class Error < StandardError; end

  JWKS_REFRESH_INTERVAL = 5.minutes
  # Net::OpenTimeout and Net::ReadTimeout are Timeout::Error subclasses.
  NETWORK_ERRORS = [ SystemCallError, SocketError, IOError, Timeout::Error, OpenSSL::SSL::SSLError ].freeze

  def self.authorize_url(state:, nonce:, code_challenge:)
    query = URI.encode_www_form(
      response_type: "code",
      client_id: config("AUTH0_CLIENT_ID"),
      redirect_uri: config("AUTH0_CALLBACK_URL"),
      scope: "openid email profile",
      connection: "google-oauth2",
      state:,
      nonce:,
      code_challenge:,
      code_challenge_method: "S256"
    )
    "#{issuer}authorize?#{query}"
  end

  def self.exchange_code(code:, code_verifier:, nonce:)
    status, body = post_token(
      grant_type: "authorization_code",
      client_id: config("AUTH0_CLIENT_ID"),
      client_secret: config("AUTH0_CLIENT_SECRET"),
      code:,
      code_verifier:,
      redirect_uri: config("AUTH0_CALLBACK_URL")
    )
    raise Error, "token endpoint returned HTTP #{status}" unless status == 200

    # Checks the RS256 signature against Auth0's keys, plus exp, iss and aud.
    claims, _header = JWT.decode(
      JSON.parse(body).fetch("id_token"), nil, true,
      algorithms: [ "RS256" ],
      jwks: ->(options) { fetch_jwks(refresh: options[:kid_not_found]) },
      iss: issuer, verify_iss: true,
      aud: config("AUTH0_CLIENT_ID"), verify_aud: true
    )
    unless nonce.present? && ActiveSupport::SecurityUtils.secure_compare(claims["nonce"].to_s, nonce)
      raise Error, "nonce mismatch"
    end

    claims
  rescue JWT::DecodeError, JSON::ParserError, KeyError, *NETWORK_ERRORS => e
    raise Error, "#{e.class}: #{e.message}"
  end

  # POSTs to Auth0's token endpoint. Returns [status, body]. Tests stub this.
  def self.post_token(params)
    uri = URI("#{issuer}oauth/token")
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.post(uri.path, URI.encode_www_form(params), "Content-Type" => "application/x-www-form-urlencoded")
    end
    [ res.code.to_i, res.body ]
  end

  # Auth0's public signing keys, cached. A token naming an unknown key triggers a refetch,
  # at most once per JWKS_REFRESH_INTERVAL so forged kids can't make us hammer Auth0. Tests stub this.
  def self.fetch_jwks(refresh: false)
    @jwks = nil if refresh && (@jwks_fetched_at.nil? || @jwks_fetched_at < JWKS_REFRESH_INTERVAL.ago)
    @jwks ||= begin
      uri = URI("#{issuer}.well-known/jwks.json")
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        http.get(uri.path)
      end
      raise Error, "JWKS request returned HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)

      @jwks_fetched_at = Time.current
      JSON.parse(res.body)
    end
  end

  def self.issuer
    "https://#{config('AUTH0_DOMAIN')}/"
  end

  def self.config(name)
    ENV.fetch(name, "").presence || raise(Error, "#{name} is not set")
  end

  private_class_method :issuer, :config
end
