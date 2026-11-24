require "test_helper"

class InteractionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "download is an event type that updates the profile" do
    assert_enqueued_with(job: UpdateUserProfileJob, args: [ users(:one) ]) do
      Interaction.create!(user: users(:one), post: posts(:two), event_type: :download)
    end
  end

  test "removing a like updates the profile" do
    assert_enqueued_with(job: UpdateUserProfileJob, args: [ users(:one) ]) do
      interactions(:one).destroy! # users(:one) likes posts(:one)
    end
  end

  test "removing a save updates the profile" do
    save = Interaction.create!(user: users(:one), post: posts(:two), event_type: :save)

    assert_enqueued_with(job: UpdateUserProfileJob, args: [ users(:one) ]) do
      save.destroy!
    end
  end

  test "a user can like a post only once" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      Interaction.create!(user: users(:one), post: posts(:one), event_type: :like) # already liked in interactions(:one)
    end
  end

  test "a user can save a post only once" do
    Interaction.create!(user: users(:one), post: posts(:two), event_type: :save)

    assert_raises(ActiveRecord::RecordNotUnique) do
      Interaction.create!(user: users(:one), post: posts(:two), event_type: :save)
    end
  end

  test "another user can like the same post" do
    assert_difference "Interaction.like_event.where(post: posts(:one)).count", 1 do
      Interaction.create!(user: users(:two), post: posts(:one), event_type: :like)
    end
  end

  test "other event types can repeat" do
    assert_difference "Interaction.click_event.count", 2 do
      2.times { Interaction.create!(user: users(:one), post: posts(:one), event_type: :click) }
    end
  end
end
