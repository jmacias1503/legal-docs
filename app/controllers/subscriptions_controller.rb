# RF-04: plan de suscripción del despacho, uso del mes y cargo estimado.
class SubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def show
    @firm = current_firm
    @usage = @firm.documents_this_month
    @history = @firm.monthly_usages.order(month: :desc).limit(12)
  end

  def update
    unless current_user.admin?
      return redirect_to subscription_path, alert: "Solo un administrador del despacho puede cambiar el plan."
    end

    if current_firm.update(params.expect(firm: %i[plan billing_cycle]))
      redirect_to subscription_path, notice: "Plan actualizado a #{current_firm.subscription_plan.name}."
    else
      redirect_to subscription_path, alert: current_firm.errors.full_messages.to_sentence
    end
  end
end
