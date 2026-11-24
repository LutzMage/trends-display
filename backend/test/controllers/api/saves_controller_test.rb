require "test_helper"

class Api::SavesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def saves_by(user)
    Interaction.save_event.where(user:, post: posts(:one))
  end

  test "saving twice stores one save and updates the profile once" do
    sign_in_as(users(:two))

    assert_difference -> { saves_by(users(:two)).count }, 1 do
      assert_enqueued_jobs 1, only: UpdateUserProfileJob do
        2.times do
          put api_post_save_url(posts(:one))

          assert_response :ok
          assert_equal({ "saved" => true }, response.parsed_body)
        end
      end
    end
  end

  test "unsaving twice removes the save and updates the profile once" do
    Interaction.create!(user: users(:two), post: posts(:one), event_type: :save)
    sign_in_as(users(:two))

    assert_difference -> { saves_by(users(:two)).count }, -1 do
      assert_enqueued_jobs 1, only: UpdateUserProfileJob do
        2.times do
          delete api_post_save_url(posts(:one))

          assert_response :ok
          assert_equal({ "saved" => false }, response.parsed_body)
        end
      end
    end
  end

  test "saving and unsaving require a signed-in user" do
    assert_no_difference -> { Interaction.count } do
      put api_post_save_url(posts(:one))
      assert_response :unauthorized

      delete api_post_save_url(posts(:one))
      assert_response :unauthorized
    end
    assert_equal({ "error" => "Not authenticated" }, response.parsed_body)
  end

  test "saving or unsaving an unknown post returns 404" do
    sign_in_as(users(:two))

    put api_post_save_url(post_id: 0)
    assert_response :not_found

    delete api_post_save_url(post_id: 0)
    assert_response :not_found
    assert_equal({ "error" => "Post not found" }, response.parsed_body)
  end
end
