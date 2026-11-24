class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :post

  normalizes :body, with: ->(body) { body.strip }

  validates :body, presence: true, length: { maximum: 250 }

  # A comment also counts as a `comment` interaction, so it feeds the author's profile (SPEC-003 §4.2).
  after_create { post.interactions.create!(user:, event_type: :comment) }

  def api_json
    { id:, body:, created_at:, user: { id: user.id, username: user.username } }
  end
end
