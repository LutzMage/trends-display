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
    download: "download",
    comment: "comment",
    skip: "skip"
  }, suffix: :event, validate: true

  belongs_to :user
  belongs_to :post

  validates :duration_ms, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Unlike and unsave delete the row, so the profile must drop that signal too.
  # One callback: after_create_commit and after_destroy_commit with the same method would override each other.
  after_commit :enqueue_profile_update, on: [ :create, :destroy ], if: :affects_profile?

  private

  def affects_profile?
    UserProfileBuilder::WEIGHTS.key?(event_type)
  end

  def enqueue_profile_update
    UpdateUserProfileJob.perform_later(user)
  end
end
