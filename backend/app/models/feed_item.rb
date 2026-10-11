class FeedItem < ApplicationRecord
  belongs_to :user
  belongs_to :post

  validates :score, presence: true, numericality: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :position, uniqueness: { scope: :user_id }
end
