require "test_helper"

class Api::Auth::GoogleControllerTest < ActionDispatch::IntegrationTest
  setup { https! } # Rails only writes Secure cookies over HTTPS outside development.

  test "start redirects to Auth0's Google connection" do
    get "/api/auth/google"

    assert_response :found
    assert_equal "https", authorize_url.scheme
    assert_equal ENV.fetch("AUTH0_DOMAIN"), authorize_url.host
    assert_equal "/authorize", authorize_url.path
    assert_equal "google-oauth2", authorize_params["connection"]
    assert_equal "code", authorize_params["response_type"]
    assert_equal "S256", authorize_params["code_challenge_method"]
    assert_equal ENV.fetch("AUTH0_CALLBACK_URL"), authorize_params["redirect_uri"]
  end

  test "start keeps state, nonce and the PKCE verifier in a short-lived Lax cookie" do
    get "/api/auth/google"

    cookie = set_cookie_line("td_oauth")
    assert cookie, "expected a td_oauth cookie"
    %w[httponly secure samesite=lax max-age=600 path=/api/auth/google].each do |attribute|
      assert_includes cookie, attribute
    end

    stored = stored_oauth_state
    assert_equal authorize_params["state"], stored["state"]
    assert_equal authorize_params["nonce"], stored["nonce"]
    assert_equal pkce_challenge(stored["verifier"]), authorize_params["code_challenge"]
    assert_in_delta Time.current.to_i, stored["at"], 5
  end

  test "start uses fresh random values each time" do
    get "/api/auth/google"
    first = authorize_params.slice("state", "nonce", "code_challenge")
    get "/api/auth/google"
    second = authorize_params.slice("state", "nonce", "code_challenge")

    first.each_key { |name| assert_not_equal first[name], second[name], "#{name} was reused" }
  end

  test "callback signs in the user whose verified Google email matches" do
    stored = start_google_sign_in

    with_google_account(email: users(:one).email) do
      get "/api/auth/google/callback", params: { code: "the-code", state: stored["state"] }
    end

    assert_redirected_to "#{ENV.fetch('FRONTEND_URL')}/"
    assert_equal({ code: "the-code", code_verifier: stored["verifier"], nonce: stored["nonce"] }, @exchange_args)

    session_cookie = set_cookie_line("td_session")
    assert session_cookie, "expected a td_session cookie"
    %w[httponly secure samesite=strict max-age=86400 path=/].each do |attribute|
      assert_includes session_cookie, attribute
    end
    assert_match(/max-age=0|expires=thu, 01 jan 1970/, set_cookie_line("td_oauth"), "td_oauth should be deleted")

    get "/api/me"
    assert_equal users(:one).id, response.parsed_body["id"]
  end

  test "callback matches the Google email regardless of letter case" do
    stored = start_google_sign_in

    with_google_account(email: users(:one).email.upcase) do
      get "/api/auth/google/callback", params: { code: "the-code", state: stored["state"] }
    end

    get "/api/me"
    assert_equal users(:one).id, response.parsed_body["id"]
  end

  test "callback reports a cancelled consent without calling Auth0" do
    stored = start_google_sign_in

    with_google_account(email: users(:one).email) do
      get "/api/auth/google/callback", params: { error: "access_denied", state: stored["state"] }
    end

    assert_google_failure "google_cancelled"
    assert_nil @exchange_args
  end

  test "callback treats any other Auth0 error as a failure" do
    stored = start_google_sign_in

    with_google_account(email: users(:one).email) do
      get "/api/auth/google/callback", params: { error: "server_error", state: stored["state"] }
    end

    assert_google_failure "google_failed"
    assert_nil @exchange_args
  end

  test "callback rejects a state that does not match the cookie without calling Auth0" do
    start_google_sign_in

    with_google_account(email: users(:one).email) do
      get "/api/auth/google/callback", params: { code: "the-code", state: "forged-state" }
    end

    assert_google_failure "google_failed"
    assert_nil @exchange_args
  end

  test "callback rejects a request without the td_oauth cookie" do
    with_google_account(email: users(:one).email) do
      get "/api/auth/google/callback", params: { code: "the-code", state: "any-state" }
    end

    assert_google_failure "google_failed"
    assert_nil @exchange_args
  end

  test "callback rejects a td_oauth cookie older than 10 minutes, even if the browser still sends it" do
    stored = start_google_sign_in
    raw_cookie = cookies["td_oauth"]

    travel 11.minutes do
      cookies["td_oauth"] = raw_cookie # the test browser would drop it; a client that ignores Max-Age would not
      with_google_account(email: users(:one).email) do
        get "/api/auth/google/callback", params: { code: "the-code", state: stored["state"] }
      end
    end

    assert_google_failure "google_failed"
    assert_nil @exchange_args
  end

  test "callback rejects a Google email that matches no user, and creates none" do
    stored = start_google_sign_in

    assert_no_difference "User.count" do
      with_google_account(email: "stranger@example.com") do
        get "/api/auth/google/callback", params: { code: "the-code", state: stored["state"] }
      end
    end

    assert_google_failure "no_account"
  end

  test "callback rejects an unverified Google email" do
    stored = start_google_sign_in

    with_google_account(email: users(:one).email, email_verified: false) do
      get "/api/auth/google/callback", params: { code: "the-code", state: stored["state"] }
    end

    assert_google_failure "email_unverified"
  end

  test "callback reports a failed code exchange" do
    stored = start_google_sign_in

    with_auth0_rejecting_the_code do
      get "/api/auth/google/callback", params: { code: "the-code", state: stored["state"] }
    end

    assert_google_failure "google_failed"
  end

  private

  # Every failure goes back to the SPA's login page with an error code and never starts a session.
  def assert_google_failure(code)
    assert_redirected_to "#{ENV.fetch('FRONTEND_URL')}/login?error=#{code}"
    assert_nil set_cookie_line("td_session"), "a failed Google sign-in must not set a session"
  end

  # Stands in for Auth0 refusing the code or returning an invalid ID token.
  def with_auth0_rejecting_the_code(&block)
    stub_singleton(Auth0Client, :exchange_code, ->(**) { raise Auth0Client::Error, "invalid_grant" }, &block)
  end

  # Runs the start step and returns what it stored in td_oauth (state, nonce, verifier, at).
  def start_google_sign_in
    get "/api/auth/google"
    stored_oauth_state
  end

  # Stands in for Auth0: exchange_code returns these ID-token claims and records its arguments in @exchange_args.
  def with_google_account(email:, email_verified: true, &block)
    claims = { "sub" => "google-oauth2|1234567890", "email" => email, "email_verified" => email_verified }
    exchange_code = lambda do |**args|
      @exchange_args = args
      claims
    end

    stub_singleton(Auth0Client, :exchange_code, exchange_code, &block)
  end

  def authorize_url
    URI(response.location)
  end

  def authorize_params
    Rack::Utils.parse_query(authorize_url.query)
  end

  # td_oauth is encrypted; read it back the way the app will.
  def stored_oauth_state
    ActionDispatch::Cookies::CookieJar.build(request, "td_oauth" => cookies["td_oauth"]).encrypted["td_oauth"]
  end

  def pkce_challenge(verifier)
    Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
  end
end
