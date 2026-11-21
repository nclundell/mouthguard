require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "email address is required and unique" do
    user = User.new(email_address: "", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"

    user.email_address = " ONE@EXAMPLE.COM "
    assert_not user.valid?
    assert_includes user.errors[:email_address], "has already been taken"
  end

  test "email address must have valid format" do
    user = User.new(email_address: "not-an-email", password: "password")

    assert_not user.valid?
    assert_includes user.errors[:email_address], "is invalid"
  end
end
