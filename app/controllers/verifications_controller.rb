# RF-03: página pública (sin sesión) para validar un documento emitido por su folio / QR.
# Solo muestra datos no sensibles (LFPDPPP): despacho, formato, fecha y huella SHA-256.
class VerificationsController < ApplicationController
  # Los PDF emitidos son pequeños; el atributo de clase permite ajustar el límite en pruebas.
  class_attribute :max_upload_bytes, instance_writer: false, default: 10.megabytes

  # La comprobación de tamaño en `create` solo acota lo que la aplicación lee a memoria
  # (máximo `max_upload_bytes`, más 1 byte como guarda). Rack ya recibió y guardó el cuerpo
  # multipart en un Tempfile antes de ejecutar el controlador (Rack::MethodOverride llama a
  # `req.POST` en cada POST), por lo que la exposición en disco y ancho de banda ante cuerpos
  # enormes solo la limita el rate limit. Un tope real requeriría un middleware Rack insertado
  # antes de Rack::MethodOverride o un límite en el proxy; no se fija de forma global porque
  # también limitaría la subida de documentos.
  rate_limit to: 20, within: 1.minute, only: :create

  before_action :set_issued_document

  def show
  end

  # Compara la huella del archivo recibido con la registrada al emitirlo.
  def create
    file = params[:file]
    return reject_upload("Selecciona un archivo PDF para comparar.") unless file.respond_to?(:read) && file.respond_to?(:size)
    return reject_upload(too_large_message) if file.size > max_upload_bytes

    # Se lee un byte de más como segunda barrera, por si el tamaño reportado no fuera fiable.
    content = file.read(max_upload_bytes + 1).to_s
    return reject_upload(too_large_message) if content.bytesize > max_upload_bytes

    @match = @issued_document.matches?(content)
    render :show
  end

  private

  def reject_upload(message)
    flash.now[:alert] = message
    render :show, status: :unprocessable_entity
  end

  def too_large_message
    "El archivo es demasiado grande (máximo #{ActiveSupport::NumberHelper.number_to_human_size(max_upload_bytes)}). Sube el PDF emitido."
  end

  def set_issued_document
    @issued_document = IssuedDocument.includes(document: :firm).find_by(token: params[:token])
    render :show, status: :not_found unless @issued_document
  end
end
