# RNF-06: el usuario genera o revoca su token para la API REST.
class ApiTokensController < ApplicationController
  before_action :authenticate_user!

  def show
  end

  # El token se muestra una sola vez, sin pasar por flash ni sesión.
  def create
    @token = current_user.regenerate_api_token!
    response.headers["Cache-Control"] = "no-store"
    render :show
  end

  def destroy
    current_user.revoke_api_token!
    redirect_to api_token_path, notice: "Token revocado."
  end
end
