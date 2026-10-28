class Firm < ApplicationRecord
  has_paper_trail

  has_many :users, dependent: :restrict_with_error
  has_many :documents, dependent: :destroy
  has_many :templates, dependent: :destroy
  has_many :monthly_usages, dependent: :destroy

  BILLING_CYCLES = { "monthly" => "Mensual", "annual" => "Anual" }.freeze

  validates :name, presence: true
  validates :plan, inclusion: { in: Plan.keys }
  validates :billing_cycle, inclusion: { in: BILLING_CYCLES.keys }

  # RF-04
  def subscription_plan = Plan.find(plan)

  def documents_this_month
    monthly_usages.find_by(month: Date.current.beginning_of_month)&.documents_count.to_i
  end

  def can_add_document? = subscription_plan.allows?(documents_this_month)
end
