require "test_helper"

class PlanTest < ActiveSupport::TestCase
  test "trial plan has a hard limit" do
    trial = Plan.find("prueba")

    assert trial.allows?(19)
    assert_not trial.allows?(20)
    assert_equal 0, trial.overage_cents(100)
  end

  test "paid plans charge overage by volume tiers" do
    basic = Plan.find("basico")

    assert basic.allows?(10_000)
    assert_equal 0, basic.overage_cents(100)
    assert_equal 10 * 5_00, basic.overage_cents(110)
    assert_equal 500 * 5_00 + 50 * 3_00, basic.overage_cents(650)
  end

  test "base price depends on billing cycle" do
    assert_equal 499_00, Plan.find("basico").base_cents("monthly")
    assert_equal 4_990_00, Plan.find("basico").base_cents("annual")
  end
end
