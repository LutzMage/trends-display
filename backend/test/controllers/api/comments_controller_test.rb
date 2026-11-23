require "test_helper"

# posts(:one) has three comments (comments.yml); posts(:two) has none.
class Api::CommentsControllerTest < ActionDispatch::IntegrationTest
  test "lists a post's comments newest first, with their authors" do
    get api_post_comments_url(posts(:one))

    assert_response :ok
    listed = response.parsed_body["comments"]
    assert_equal [ comments(:newest), comments(:middle), comments(:oldest) ].map(&:id), listed.pluck("id")
    assert_equal %w[body created_at id user], listed.first.keys.sort
    assert_equal({ "id" => users(:two).id, "username" => users(:two).username }, listed.last["user"])
  end

  test "a post without comments lists none" do
    get api_post_comments_url(posts(:two))

    assert_response :ok
    assert_equal({ "comments" => [] }, response.parsed_body)
  end

  test "a signed-in user can comment, which also records a comment interaction" do
    sign_in_as(users(:two))

    assert_difference [ "Comment.count", "Interaction.comment_event.count" ], 1 do
      post api_post_comments_url(posts(:one)), params: { comment: { body: "  Nice!  " } }, as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal "Nice!", body["body"]
    assert_equal({ "id" => users(:two).id, "username" => users(:two).username }, body["user"])
  end

  test "a blank or too long comment is rejected" do
    sign_in_as(users(:two))

    {
      "" => "Body can't be blank",
      "   " => "Body can't be blank",
      "a" * 251 => "Body is too long (maximum is 250 characters)"
    }.each do |body, error|
      assert_no_difference [ "Comment.count", "Interaction.count" ] do
        post api_post_comments_url(posts(:one)), params: { comment: { body: } }, as: :json
      end

      assert_response :unprocessable_entity
      assert_includes response.parsed_body["errors"], error
    end
  end

  test "commenting requires a signed-in user" do
    assert_no_difference "Comment.count" do
      post api_post_comments_url(posts(:one)), params: { comment: { body: "Hi" } }, as: :json
    end

    assert_response :unauthorized
    assert_equal({ "error" => "Not authenticated" }, response.parsed_body)
  end

  test "listing or commenting on an unknown post returns 404" do
    get api_post_comments_url(post_id: 0)
    assert_response :not_found

    sign_in_as(users(:two))
    post api_post_comments_url(post_id: 0), params: { comment: { body: "Hi" } }, as: :json
    assert_response :not_found
    assert_equal({ "error" => "Post not found" }, response.parsed_body)
  end
end
