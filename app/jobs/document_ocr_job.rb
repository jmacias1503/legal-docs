# Procesa el OCR fuera del hilo web (RNF-03) y guarda texto y datos detectados.
class DocumentOcrJob < ApplicationJob
  queue_as :default

  def perform(document)
    return unless document.file.attached?

    text = document.file.open { |file| OcrExtractor.call(file.path, document.file.content_type) }
    # Los datos capturados a mano tienen prioridad sobre los detectados.
    metadata = LegalFields.extract(text).merge(document.metadata.to_h.compact_blank)
    document.update!(extracted_text: text, metadata:, status: :completed, ocr_error: nil)
  rescue OcrExtractor::Error => e
    # Sin validar: el error debe quedar registrado aunque el archivo sea el problema.
    document.assign_attributes(status: :error, ocr_error: e.message)
    document.save!(validate: false)
  end
end
