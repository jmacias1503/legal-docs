require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "new users without firm get a personal firm" do
    user = User.create!(email: "nuevo@mx.mx", password: "password123", first_name: "Nuevo", last_name: "Usuario")

    assert_equal "Despacho de Nuevo Usuario", user.firm.name
  end

  test "keeps the given firm" do
    user = User.create!(email: "otro@mx.mx", password: "password123", first_name: "Otro", last_name: "Usuario", firm: firms(:one))

    assert_equal firms(:one), user.firm
  end

  test "the creator of a personal firm administers it" do
    user = User.create!(email: "admin@mx.mx", password: "password123", first_name: "Ad", last_name: "Min")

    assert user.admin?
    assert_not User.create!(email: "x@mx.mx", password: "password123", first_name: "X", last_name: "Y", firm: firms(:one)).admin?
  end

  test "api token is stored as a digest and can be revoked" do
    user = users(:one)
    token = user.regenerate_api_token!

    assert_not_equal token, user.api_token_digest
    assert_equal user, User.find_by_api_token(token)
    assert_nil User.find_by_api_token("otro")

    user.revoke_api_token!
    assert_nil User.find_by_api_token(token)
  end
end
