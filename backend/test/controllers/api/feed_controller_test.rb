require "test_helper"

# The feed wraps around when it runs out (FR-FEED-07), so posts repeat within a page.
# These tests compare the distinct post ids, in the order they first appear.
class Api::FeedControllerTest < ActionDispatch::IntegrationTest
  test "anonymous visitors get every post, newest first" do
    get "/api/feed"

    assert_response :ok
    assert_equal [ posts(:one).id, posts(:two).id ].sort, distinct_post_ids.sort
    assert_equal distinct_post_ids.sort.reverse, distinct_post_ids, "expected newest (highest id) first"
  end

  test "a user_id parameter is ignored" do
    get "/api/feed", params: { user_id: users(:two).id }

    assert_equal [ posts(:one).id, posts(:two).id ].sort, distinct_post_ids.sort
  end

  test "a signed-in user gets a ranked feed without their own posts" do
    sign_in_as(users(:two)) # bob has a profile embedding (fixture two_profile) and wrote post two

    get "/api/feed"

    assert_response :ok
    assert_equal [ posts(:one).id ], distinct_post_ids
  end

  private

  def distinct_post_ids
    response.parsed_body["posts"].map { |post| post["id"] }.uniq
  end
end
