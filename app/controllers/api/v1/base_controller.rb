# RNF-06: API REST para integrar CRMs. Autenticación: "Authorization: Bearer <token>".
module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate!
      before_action :set_paper_trail_whodunnit

      rescue_from(ActiveRecord::RecordNotFound) { render json: { error: "No encontrado" }, status: :not_found }
      rescue_from(ActionController::ParameterMissing) { |e| render json: { error: e.message }, status: :bad_request }

      private

      attr_reader :current_user

      def current_firm = current_user.firm

      def authenticate!
        @current_user = authenticate_with_http_token { |token, _options| User.find_by_api_token(token) }
        render json: { error: "Token inválido o ausente" }, status: :unauthorized unless @current_user
      end
    end
  end
end
