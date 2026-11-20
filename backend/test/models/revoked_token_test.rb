require "test_helper"

class RevokedTokenTest < ActiveSupport::TestCase
  setup { @claims = { "jti" => SecureRandom.uuid, "exp" => 1.hour.from_now.to_i } }

  test "revoke! records the jti and its expiry" do
    RevokedToken.revoke!(@claims)

    token = RevokedToken.find_by!(jti: @claims["jti"])
    assert_equal Time.zone.at(@claims["exp"]), token.expires_at
  end

  test "revoking the same token twice keeps one row" do
    RevokedToken.revoke!(@claims)

    assert_no_difference("RevokedToken.count") { RevokedToken.revoke!(@claims) }
  end

  test "revoked? tells revoked and active tokens apart" do
    RevokedToken.revoke!(@claims)

    assert RevokedToken.revoked?(@claims["jti"])
    assert_not RevokedToken.revoked?(SecureRandom.uuid)
  end
end
