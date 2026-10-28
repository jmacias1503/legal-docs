# RF-03: página pública (sin sesión) para validar un documento emitido por su folio / QR.
# Solo muestra datos no sensibles (LFPDPPP): despacho, formato, fecha y huella SHA-256.
class VerificationsController < ApplicationController
  rate_limit to: 20, within: 1.minute, only: :create

  before_action :set_issued_document

  def show
  end

  # Compara la huella del archivo recibido con la registrada al emitirlo.
  def create
    file = params[:file]
    @match = @issued_document.matches?(file.read) if file.respond_to?(:read)
    render :show
  end

  private

  def set_issued_document
    @issued_document = IssuedDocument.includes(document: :firm).find_by(token: params[:token])
    render :show, status: :not_found unless @issued_document
  end
end
