class User < ApplicationRecord
  has_many :posts, dependent: :destroy
  has_many :interactions, dependent: :destroy
  has_many :feed_items, dependent: :destroy
  has_many :embeddings, as: :embeddable, dependent: :destroy

  validates :username, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }
end
