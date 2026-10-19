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
end
