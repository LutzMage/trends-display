require "test_helper"

class CommentTest < ActiveSupport::TestCase
  def build_comment(body)
    Comment.new(user: users(:one), post: posts(:two), body:)
  end

  test "requires a body" do
    assert_not build_comment("").valid?
    assert_not build_comment("   ").valid?
  end

  test "allows at most 250 characters, counted after stripping" do
    assert build_comment("  #{'a' * 250}  ").valid?
    assert_not build_comment("a" * 251).valid?
  end

  test "strips surrounding spaces" do
    assert_equal "Nice!", build_comment("  Nice!  ").body
  end

  test "creating a comment records a comment interaction for its author and post" do
    assert_difference -> { Interaction.comment_event.where(user: users(:one), post: posts(:two)).count }, 1 do
      build_comment("Nice!").save!
    end
  end

  test "an invalid comment records no interaction" do
    assert_no_difference "Interaction.count" do
      build_comment(" ").save
    end
  end

  test "api_json has the comment and its author" do
    comment = build_comment("Nice!")
    comment.save!

    assert_equal(
      { id: comment.id, body: "Nice!", created_at: comment.created_at,
        user: { id: users(:one).id, username: users(:one).username } },
      comment.api_json
    )
  end
end
