require "test_helper"

class Api::MeControllerTest < ActionDispatch::IntegrationTest
  NOT_AUTHENTICATED = { "error" => "Not authenticated" }.freeze

  setup do
    https!
    @user = users(:one)
  end

  test "returns the signed-in user" do
    sign_in_as(@user)

    get "/api/me"

    assert_response :ok
    assert_equal({ "id" => @user.id, "username" => @user.username, "email" => @user.email }, response.parsed_body)
  end

  test "rejects a request without a session cookie" do
    get "/api/me"

    assert_unauthenticated
  end

  test "rejects an expired token" do
    sign_in_as(@user)

    travel(24.hours + 1.second) { get "/api/me" }

    assert_unauthenticated
  end

  test "rejects a tampered token" do
    cookies[:td_session] = "#{SessionToken.issue(@user)}x"

    get "/api/me"

    assert_unauthenticated
  end

  test "rejects a revoked token" do
    token = SessionToken.issue(@user)
    RevokedToken.revoke!(SessionToken.decode(token))
    cookies[:td_session] = token

    get "/api/me"

    assert_unauthenticated
  end

  test "rejects a token for a deleted user" do
    sign_in_as(@user)
    @user.destroy!

    get "/api/me"

    assert_unauthenticated
  end

  private

  def assert_unauthenticated
    assert_response :unauthorized
    assert_equal NOT_AUTHENTICATED, response.parsed_body
  end
end
