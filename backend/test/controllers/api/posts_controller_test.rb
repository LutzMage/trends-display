require "test_helper"

class Api::PostsControllerTest < ActionDispatch::IntegrationTest
  test "show returns the post in feed shape" do
    post = posts(:one)

    get api_post_url(post)

    assert_response :ok
    body = response.parsed_body
    assert_equal %w[created_at id media_type media_url text user], body.keys.sort
    assert_equal post.id, body["id"]
    assert_equal post.text, body["text"]
    assert_equal "image", body["media_type"]
    assert_equal post.media_url, body["media_url"]
    assert_equal({ "id" => users(:one).id, "username" => users(:one).username }, body["user"])
  end

  test "show returns text-only posts with null media" do
    get api_post_url(posts(:two))

    assert_response :ok
    body = response.parsed_body
    assert_nil body["media_type"]
    assert_nil body["media_url"]
    assert_equal users(:two).username, body.dig("user", "username")
  end

  test "show returns 404 for an unknown post" do
    get api_post_url(id: 0)

    assert_response :not_found
    assert_equal({ "error" => "Post not found" }, response.parsed_body)
  end

  test "create requires a signed-in user" do
    assert_no_difference "Post.count" do
      post api_posts_url, params: { post: { text: "Hello", user_id: users(:one).id } }, as: :json
    end

    assert_response :unauthorized
    assert_equal({ "error" => "Not authenticated" }, response.parsed_body)
  end

  test "create makes the signed-in user the author, whatever user_id is sent" do
    sign_in_as(users(:two))

    assert_difference "Post.count", 1 do
      post api_posts_url, params: { post: { text: "Hello", user_id: users(:one).id } }, as: :json
    end

    assert_response :created
    assert_equal users(:two), Post.find(response.parsed_body["id"]).user
  end

  test "create reports validation errors for a signed-in user" do
    sign_in_as(users(:two))

    post api_posts_url, params: { post: { text: "" } }, as: :json

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Text can't be blank"
  end
end
