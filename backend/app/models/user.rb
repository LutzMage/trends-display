class User < ApplicationRecord
  has_secure_password

  # Lower-cased so sign-in and Google email matching ignore case.
  normalizes :email, with: ->(email) { email.strip.downcase }

  has_many :posts, dependent: :destroy
  has_many :interactions, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :feed_items, dependent: :destroy
  has_many :embeddings, as: :embeddable, dependent: :destroy

  has_one :profile_embedding,
    -> { user_profile.where(embedding_model: IaService::EMBED_MODEL) },
    as: :embeddable, class_name: "Embedding"

  validates :username, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }

  # The signed-in user as returned by /api/me and sign-in.
  def account_json
    { id:, username:, email: }
  end
end
