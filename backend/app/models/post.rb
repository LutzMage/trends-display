class Post < ApplicationRecord
  # New media types can be added here as they're supported (e.g. video, audio).
  enum :media_type, { image: "image" }, validate: { allow_nil: true }

  belongs_to :user
  has_many :interactions, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :feed_items, dependent: :destroy
  has_many :embeddings, as: :embeddable, dependent: :destroy

  validates :text, presence: true, length: { maximum: 250 }
  validates :media_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) },
    if: :media_type?
  validates :media_url, absence: true, unless: :media_type?

  after_create_commit :enqueue_embeddings

  def feed_json
    {
      id:, text:, media_type:, media_url:, created_at:,
      user: { id: user.id, username: user.username }
    }
  end

  # The open post: feed_json plus counts and the viewer's own like/save state. viewer is nil when anonymous.
  def detail_json(viewer)
    feed_json.merge(
      like_count: interactions.like_event.count,
      comment_count: comments.count,
      liked: viewer.present? && interactions.like_event.exists?(user: viewer),
      saved: viewer.present? && interactions.save_event.exists?(user: viewer)
    )
  end

  private

  def enqueue_embeddings
    GenerateEmbeddingsJob.perform_later(self)
  end
end
