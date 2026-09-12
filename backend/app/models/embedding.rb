class Embedding < ApplicationRecord
  MAX_DIMENSIONS = 768

  enum :embedding_type, {
    text: "text",
    image: "image",
    audio: "audio",
    video: "video",
    semantic: "semantic",
    user_profile: "user_profile"
  }, validate: true

  belongs_to :embeddable, polymorphic: true

  # The `vector` column is a fixed-size pgvector(768) column shared by every
  # embedding type so they can live in one table/index. `dimensions` records
  # how many of those 768 slots are meaningful for this row's source model;
  # any remainder is expected to be zero-padded by the writer.
  has_neighbors :vector, dimensions: MAX_DIMENSIONS

  validates :embedding_model, presence: true
  validates :dimensions, presence: true,
    numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_DIMENSIONS }
end
