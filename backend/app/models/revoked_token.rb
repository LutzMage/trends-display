# Session JWTs revoked by sign-out (SPEC-002 §4.3). Rows can be pruned once expires_at has passed.
class RevokedToken < ApplicationRecord
  validates :jti, presence: true, uniqueness: true
  validates :expires_at, presence: true

  def self.revoke!(claims)
    insert_all(
      [ { jti: claims.fetch("jti"), expires_at: Time.zone.at(claims.fetch("exp")) } ],
      unique_by: :jti
    )
  end

  def self.revoked?(jti)
    exists?(jti: jti)
  end
end
