require "test_helper"

class SessionTokenTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "issue then decode returns the user's claims" do
    claims = SessionToken.decode(SessionToken.issue(@user))

    assert_equal @user.id.to_s, claims["sub"]
    assert_match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/, claims["jti"])
    assert_equal claims["iat"] + 24.hours.to_i, claims["exp"]
  end

  test "each token gets a unique jti" do
    first = SessionToken.decode(SessionToken.issue(@user))
    second = SessionToken.decode(SessionToken.issue(@user))

    assert_not_equal first["jti"], second["jti"]
  end

  test "an expired token decodes to nil" do
    token = SessionToken.issue(@user)

    travel(24.hours + 1.second) { assert_nil SessionToken.decode(token) }
  end

  test "a token with a changed payload decodes to nil" do
    header, _payload, signature = SessionToken.issue(@user).split(".")
    forged = Base64.urlsafe_encode64({ sub: "999", jti: SecureRandom.uuid, exp: 1.hour.from_now.to_i }.to_json, padding: false)

    assert_nil SessionToken.decode([ header, forged, signature ].join("."))
  end

  test "a token signed with another secret decodes to nil" do
    token = JWT.encode({ sub: @user.id.to_s, jti: SecureRandom.uuid, exp: 1.hour.from_now.to_i }, "another-secret", "HS256")

    assert_nil SessionToken.decode(token)
  end

  test "an unsigned token decodes to nil" do
    token = JWT.encode({ sub: @user.id.to_s, jti: SecureRandom.uuid, exp: 1.hour.from_now.to_i }, nil, "none")

    assert_nil SessionToken.decode(token)
  end

  test "a token without a jti decodes to nil" do
    token = JWT.encode({ sub: @user.id.to_s, exp: 1.hour.from_now.to_i }, ENV.fetch("JWT_SECRET"), "HS256")

    assert_nil SessionToken.decode(token)
  end

  test "garbage and nil decode to nil" do
    assert_nil SessionToken.decode("not-a-jwt")
    assert_nil SessionToken.decode(nil)
  end
end
