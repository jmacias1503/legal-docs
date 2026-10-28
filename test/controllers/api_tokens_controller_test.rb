require "test_helper"

class ApiTokensControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:one) }

  test "generates a token shown only once" do
    post api_token_path

    token = response.body[/<code[^>]*>(\w+)<\/code>/, 1]
    assert_equal users(:one), User.find_by_api_token(token)

    get api_token_path
    assert_no_match token, response.body
  end

  test "revokes the token" do
    users(:one).regenerate_api_token!
    delete api_token_path

    assert_nil users(:one).reload.api_token_digest
  end
end
