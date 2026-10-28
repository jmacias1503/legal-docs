# Extrae el texto del archivo de una plantilla para usarlo como cuerpo editable (RF-05).
class TemplateTextJob < ApplicationJob
  queue_as :default

  def perform(template)
    return if template.body.present? || !template.file.attached?

    text = template.file.open { |file| OcrExtractor.call(file.path, template.file.content_type) }
    template.update!(body: text)
  rescue OcrExtractor::Error => e
    Rails.logger.warn("No se pudo extraer texto de la plantilla #{template.id}: #{e.message}")
  end
end
