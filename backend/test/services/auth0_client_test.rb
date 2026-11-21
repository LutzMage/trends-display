require "test_helper"

class Auth0ClientTest < ActiveSupport::TestCase
  # One key pair for the class: Auth0 would sign with KEY; OTHER_KEY stands in for a forger.
  KEY = OpenSSL::PKey::RSA.new(2048)
  OTHER_KEY = OpenSSL::PKey::RSA.new(2048)
  JWK = JWT::JWK.new(KEY, { kid: "test-key", alg: "RS256", use: "sig" })
  JWKS = JSON.parse({ keys: [ JWK.export ] }.to_json) # string keys, as Auth0 returns them

  test "authorize_url sends the user to Auth0's Google connection with state, nonce and PKCE" do
    url = URI(Auth0Client.authorize_url(state: "the-state", nonce: "the-nonce", code_challenge: "the-challenge"))

    assert_equal "https", url.scheme
    assert_equal ENV.fetch("AUTH0_DOMAIN"), url.host
    assert_equal "/authorize", url.path
    # Exact match, so a missing or unexpected parameter fails the test.
    assert_equal(
      {
        "response_type" => "code",
        "client_id" => ENV.fetch("AUTH0_CLIENT_ID"),
        "redirect_uri" => ENV.fetch("AUTH0_CALLBACK_URL"),
        "scope" => "openid email profile",
        "connection" => "google-oauth2",
        "state" => "the-state",
        "nonce" => "the-nonce",
        "code_challenge" => "the-challenge",
        "code_challenge_method" => "S256"
      },
      Rack::Utils.parse_query(url.query)
    )
  end

  test "exchange_code posts the code and verifier and returns the verified claims" do
    claims = exchange

    assert_equal "alice@example.com", claims["email"]
    assert_equal true, claims["email_verified"]
    assert_equal(
      {
        grant_type: "authorization_code",
        client_id: ENV.fetch("AUTH0_CLIENT_ID"),
        client_secret: ENV.fetch("AUTH0_CLIENT_SECRET"),
        code: "the-code",
        code_verifier: "the-verifier",
        redirect_uri: ENV.fetch("AUTH0_CALLBACK_URL")
      },
      @token_request
    )
  end

  test "exchange_code rejects a token signed with another key" do
    assert_rejected id_token: signed_token(key: OTHER_KEY)
  end

  test "exchange_code rejects a token from another issuer" do
    assert_rejected id_token: signed_token(iss: "https://evil.example/")
  end

  test "exchange_code rejects a token for another audience" do
    assert_rejected id_token: signed_token(aud: "another-client")
  end

  test "exchange_code rejects an expired token" do
    assert_rejected id_token: signed_token(exp: 1.minute.ago.to_i)
  end

  test "exchange_code rejects a token whose nonce does not match" do
    assert_rejected id_token: signed_token(nonce: "another-nonce")
  end

  test "exchange_code rejects a token-endpoint error" do
    assert_rejected status: 403
  end

  test "exchange_code wraps network failures" do
    assert_rejected network_error: Errno::ECONNREFUSED
  end

  private

  # Calls exchange_code against a fake Auth0. The token endpoint answers with `status` and `id_token`
  # (or raises `network_error`) and records what it received in @token_request; the key download returns JWKS.
  def exchange(id_token: signed_token, status: 200, network_error: nil)
    token_endpoint = lambda do |params|
      @token_request = params
      raise network_error if network_error

      [ status, { id_token: }.to_json ]
    end

    stub_singleton(Auth0Client, :fetch_jwks, ->(refresh: false) { JWKS }) do
      stub_singleton(Auth0Client, :post_token, token_endpoint) do
        Auth0Client.exchange_code(code: "the-code", code_verifier: "the-verifier", nonce: "the-nonce")
      end
    end
  end

  def assert_rejected(**fake_auth0)
    assert_raises(Auth0Client::Error) { exchange(**fake_auth0) }
  end

  # An ID token as Auth0 would issue it, signed with KEY unless told otherwise.
  def signed_token(key: KEY, **overrides)
    claims = {
      iss: "https://#{ENV.fetch('AUTH0_DOMAIN')}/",
      aud: ENV.fetch("AUTH0_CLIENT_ID"),
      sub: "google-oauth2|1234567890",
      iat: Time.current.to_i,
      exp: 1.hour.from_now.to_i,
      nonce: "the-nonce",
      email: "alice@example.com",
      email_verified: true
    }.merge(overrides)

    JWT.encode(claims, key, "RS256", kid: JWK.kid)
  end
end
