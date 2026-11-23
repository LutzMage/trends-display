require "test_helper"

class Api::InteractionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "records click, share and download for the signed-in user" do
    sign_in_as(users(:two))

    %w[click share download].each do |event_type|
      assert_difference -> { Interaction.where(user: users(:two), post: posts(:one), event_type:).count }, 1 do
        assert_enqueued_with(job: UpdateUserProfileJob, args: [ users(:two) ]) do
          post api_post_interactions_url(posts(:one)), params: { event_type: }, as: :json
        end
      end

      assert_response :created
      assert_empty response.body
    end
  end

  test "rejects event types that have their own endpoint or are not recorded" do
    sign_in_as(users(:two))

    %w[like save comment impression view bogus].each do |event_type|
      assert_no_difference "Interaction.count" do
        post api_post_interactions_url(posts(:one)), params: { event_type: }, as: :json
      end

      assert_response :unprocessable_entity
      assert_equal({ "errors" => [ "Event type is not allowed" ] }, response.parsed_body)
    end
  end

  test "recording requires a signed-in user" do
    assert_no_difference "Interaction.count" do
      post api_post_interactions_url(posts(:one)), params: { event_type: "click" }, as: :json
    end

    assert_response :unauthorized
    assert_equal({ "error" => "Not authenticated" }, response.parsed_body)
  end

  test "recording on an unknown post returns 404" do
    sign_in_as(users(:two))

    post api_post_interactions_url(post_id: 0), params: { event_type: "click" }, as: :json

    assert_response :not_found
    assert_equal({ "error" => "Post not found" }, response.parsed_body)
  end
end
