require "test_helper"

# Defence in depth against CSRF (SPEC-002 §4.5, AC-20): a state-changing request that says it
# comes from another site is refused. Requests without an Origin header (curl, tests) are allowed.
class Api::OriginCheckTest < ActionDispatch::IntegrationTest
  FOREIGN = { "Origin" => "https://evil.example" }.freeze

  setup do
    Api::Auth::SessionsController::RATE_LIMIT_STORE.clear
    @user = users(:one)
    @credentials = { email: @user.email, password: "password" }
  end

  test "a POST from a foreign origin is refused" do
    post "/api/auth/sign_in", params: @credentials, as: :json, headers: FOREIGN

    assert_forbidden_origin
  end

  test "a DELETE from a foreign origin is refused and leaves the session alone" do
    sign_in_as(@user)

    delete "/api/auth/sign_out", headers: FOREIGN

    assert_forbidden_origin
    get "/api/me"
    assert_response :ok
  end

  test "a POST from the SPA's origin is handled normally" do
    post "/api/auth/sign_in", params: @credentials, as: :json,
      headers: { "Origin" => Rails.application.config.x.frontend_url }

    assert_response :ok
  end

  test "a POST without an Origin header is handled normally" do
    post "/api/auth/sign_in", params: @credentials, as: :json

    assert_response :ok
  end

  test "a GET from a foreign origin is never refused" do
    get "/api/feed", headers: FOREIGN

    assert_response :ok
  end

  private

  def assert_forbidden_origin
    assert_response :forbidden
    assert_equal({ "error" => "Forbidden origin" }, response.parsed_body)
  end
end
