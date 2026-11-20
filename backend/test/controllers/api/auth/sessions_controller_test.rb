require "test_helper"

class Api::Auth::SessionsControllerTest < ActionDispatch::IntegrationTest
  INVALID = { "error" => "Invalid email or password" }.freeze

  setup do
    https! # Rails only writes Secure cookies over HTTPS outside development.
    Api::Auth::SessionsController::RATE_LIMIT_STORE.clear
    @user = users(:one)
  end

  test "sign in returns the user and sets a secure session cookie" do
    post "/api/auth/sign_in", params: { email: @user.email, password: "password" }, as: :json

    assert_response :ok
    assert_equal({ "id" => @user.id, "username" => @user.username, "email" => @user.email }, response.parsed_body)

    cookie = set_cookie_line("td_session")
    assert cookie, "expected a td_session cookie"
    %w[httponly secure samesite=strict max-age=86400 path=/].each do |attribute|
      assert_includes cookie, attribute
    end
  end

  test "sign in never puts the token in the body" do
    post "/api/auth/sign_in", params: { email: @user.email, password: "password" }, as: :json

    assert_not_includes response.body, cookies[:td_session]
  end

  test "sign in ignores the email's letter case" do
    post "/api/auth/sign_in", params: { email: "ALICE@Example.com", password: "password" }, as: :json

    assert_response :ok
  end

  test "a wrong password, an unknown email and a missing field get the same 401" do
    [
      { email: @user.email, password: "wrong-password" },
      { email: "nobody@example.com", password: "password" },
      { email: @user.email },
      {}
    ].each do |params|
      post "/api/auth/sign_in", params: params, as: :json

      assert_response :unauthorized
      assert_equal INVALID, response.parsed_body
      assert_nil set_cookie_line("td_session"), "no session cookie for #{params.keys}"
    end
  end

  test "the 11th sign-in attempt within 3 minutes is rate limited" do
    10.times do
      post "/api/auth/sign_in", params: { email: @user.email, password: "wrong-password" }, as: :json
      assert_response :unauthorized
    end

    post "/api/auth/sign_in", params: { email: @user.email, password: "password" }, as: :json

    assert_response :too_many_requests
    assert_equal({ "error" => "Too many attempts. Try again later." }, response.parsed_body)
  end

  test "sign out revokes the token and clears the cookie" do
    post "/api/auth/sign_in", params: { email: @user.email, password: "password" }, as: :json
    token = cookies[:td_session]

    delete "/api/auth/sign_out"

    assert_response :no_content
    assert_match(/max-age=0|expires=thu, 01 jan 1970/, set_cookie_line("td_session"))

    cookies[:td_session] = token
    get "/api/me"
    assert_response :unauthorized
  end

  test "sign out without a session still succeeds" do
    delete "/api/auth/sign_out"

    assert_response :no_content
  end
end
