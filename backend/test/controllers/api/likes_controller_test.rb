require "test_helper"

# users(:one) already likes posts(:one) (interactions.yml); users(:two) does not.
class Api::LikesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def likes_on(post)
    Interaction.like_event.where(post:)
  end

  test "liking twice stores one like and updates the profile once" do
    sign_in_as(users(:two))

    assert_difference -> { likes_on(posts(:one)).count }, 1 do
      assert_enqueued_jobs 1, only: UpdateUserProfileJob do
        2.times do
          put api_post_like_url(posts(:one))

          assert_response :ok
          assert_equal({ "liked" => true, "like_count" => 2 }, response.parsed_body)
        end
      end
    end
  end

  test "unliking twice removes the like and updates the profile once" do
    sign_in_as(users(:one))

    assert_difference -> { likes_on(posts(:one)).count }, -1 do
      assert_enqueued_jobs 1, only: UpdateUserProfileJob do
        2.times do
          delete api_post_like_url(posts(:one))

          assert_response :ok
          assert_equal({ "liked" => false, "like_count" => 0 }, response.parsed_body)
        end
      end
    end
  end

  test "liking and unliking require a signed-in user" do
    assert_no_difference -> { Interaction.count } do
      put api_post_like_url(posts(:one))
      assert_response :unauthorized

      delete api_post_like_url(posts(:one))
      assert_response :unauthorized
    end
    assert_equal({ "error" => "Not authenticated" }, response.parsed_body)
  end

  test "liking or unliking an unknown post returns 404" do
    sign_in_as(users(:two))

    put api_post_like_url(post_id: 0)
    assert_response :not_found

    delete api_post_like_url(post_id: 0)
    assert_response :not_found
    assert_equal({ "error" => "Post not found" }, response.parsed_body)
  end

  test "a request from a foreign origin cannot like" do
    sign_in_as(users(:two))

    assert_no_difference -> { Interaction.count } do
      put api_post_like_url(posts(:one)), headers: { "Origin" => "https://evil.example" }
    end
    assert_response :forbidden
  end
end
