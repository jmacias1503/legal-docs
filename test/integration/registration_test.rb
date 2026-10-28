require "test_helper"

class RegistrationTest < ActionDispatch::IntegrationTest
  test "new user can sign up with name and gets a personal firm" do
    post user_registration_path, params: { user: {
      first_name: "Laura", last_name: "Ríos", email: "laura@mx.mx",
      password: "password123", password_confirmation: "password123"
    } }

    assert_redirected_to root_path
    assert_equal "Despacho de Laura Ríos", User.find_by(email: "laura@mx.mx").firm.name
  end
end
