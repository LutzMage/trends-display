class Post < ApplicationRecord
  # New media types can be added here as they're supported (e.g. video, audio).
  enum :media_type, { image: "image" }, validate: { allow_nil: true }

  belongs_to :user
  has_many :interactions, dependent: :destroy
  has_many :feed_items, dependent: :destroy
  has_many :embeddings, as: :embeddable, dependent: :destroy

  validates :text, presence: true, length: { maximum: 250 }
  validates :media_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) },
    if: :media_type?
  validates :media_url, absence: true, unless: :media_type?
end
