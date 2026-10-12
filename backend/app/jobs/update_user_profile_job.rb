class UpdateUserProfileJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(user) { user }, duration: 5.minutes

  def perform(user)
    UserProfileBuilder.new(user).call
  end
end
