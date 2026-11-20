require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "a new user requires a password" do
    user = User.new(username: "carol", email: "carol@example.com")

    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "a new user with a password is valid" do
    user = User.new(username: "carol", email: "carol@example.com", password: "secret-password")

    assert user.valid?
  end

  test "authenticate accepts the right password and rejects a wrong one" do
    user = users(:one)

    assert_equal user, user.authenticate("password")
    assert_not user.authenticate("wrong-password")
  end

  test "email is stored stripped and lower-cased" do
    user = User.new(email: "  Carol@Example.COM ")

    assert_equal "carol@example.com", user.email
  end

  test "email lookups match regardless of case" do
    assert_equal users(:one), User.find_by(email: "ALICE@example.com")
  end
end
