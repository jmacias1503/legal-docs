require "test_helper"

class SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  test "shows plan and monthly usage" do
    sign_in users(:one)
    firms(:one).documents.create!(title: "Uno", user: users(:one))

    get subscription_path

    assert_response :success
    assert_match "Prueba gratuita", response.body
    assert_match "1 / 20", response.body
  end

  test "admins can change the plan" do
    sign_in users(:one)
    patch subscription_path, params: { firm: { plan: "profesional", billing_cycle: "annual" } }

    assert_equal %w[profesional annual], firms(:one).reload.slice(:plan, :billing_cycle).values
  end

  test "rejects unknown plans" do
    sign_in users(:one)
    patch subscription_path, params: { firm: { plan: "gratis" } }

    assert_equal "prueba", firms(:one).reload.plan
    assert flash[:alert].present?
  end

  test "other roles cannot change the plan" do
    sign_in users(:assistant)
    patch subscription_path, params: { firm: { plan: "notaria" } }

    assert_equal "prueba", firms(:one).reload.plan
  end
end
