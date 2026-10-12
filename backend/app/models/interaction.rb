class Interaction < ApplicationRecord
  enum :event_type, {
    impression: "impression",
    click: "click",
    view: "view",
    watch: "watch",
    like: "like",
    dislike: "dislike",
    save: "save",
    share: "share",
    comment: "comment",
    skip: "skip"
  }, suffix: :event, validate: true

  belongs_to :user
  belongs_to :post

  validates :duration_ms, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  after_create_commit :enqueue_profile_update, if: :affects_profile?

  private

  def affects_profile?
    UserProfileBuilder::WEIGHTS.key?(event_type)
  end

  def enqueue_profile_update
    UpdateUserProfileJob.perform_later(user)
  end
end
