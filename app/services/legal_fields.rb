# Catálogo de datos jurídicos que el sistema sabe detectar en un texto (RF-01)
# y validar antes de usarlos en un autollenado (RF-02).
module LegalFields
  NAME = "[A-ZÁÉÍÓÚÑ]+(?:[ \\t]+[A-ZÁÉÍÓÚÑ]+){1,4}"
  MONTHS = "enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre"

  # extract: regex con un grupo de captura sobre el texto completo.
  # labeled + layout: búsqueda tolerante junto a su etiqueta ("RFC ...") que corrige
  #   confusiones típicas del OCR según la posición (L = letra, D = dígito, A = cualquiera).
  # format: regex que debe cumplir el valor completo (opcional).
  FIELDS = {
    "nombre" => { label: "Nombre (parte principal)", extract: /\bC\.\s+(#{NAME})/ },
    "contraparte" => { label: "Contraparte", extract: /\bC\.\s+#{NAME}.*?\bC\.\s+(#{NAME})/m },
    "rfc" => { label: "RFC", extract: /\b([A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3})\b/,
               labeled: /\bRFC[:.\s]*([A-Z0-9Ñ&@]{12,13})\b/,
               layout: ->(token) { "L" * (token.length - 9) + "DDDDDDAAA" },
               format: /\A[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3}\z/ },
    "curp" => { label: "CURP", extract: /\b([A-Z][AEIOUX][A-Z]{2}\d{6}[HM][A-Z]{5}[A-Z0-9]\d)\b/,
                labeled: /\bCURP[:.\s]*([A-Z0-9@]{18})\b/,
                layout: ->(_token) { "LLLLDDDDDDLLLLLLAD" },
                format: /\A[A-Z][AEIOUX][A-Z]{2}\d{6}[HM][A-Z]{5}[A-Z0-9]\d\z/ },
    "fecha" => { label: "Fecha", extract: /\b(\d{1,2}\/\d{1,2}\/\d{4}|\d{1,2} de (?:#{MONTHS}) de(?:l)? \d{4})\b/i,
                 format: /\A(\d{1,2}\/\d{1,2}\/\d{4}|\d{1,2} de (?:#{MONTHS}) de(?:l)? \d{4})\z/i },
    "monto" => { label: "Monto", extract: /(\$\s?\d{1,3}(?:,\d{3})*(?:\.\d{2})?)/,
                 format: /\A\$\s?\d{1,3}(?:,?\d{3})*(?:\.\d{2})?\z/ },
    "expediente" => { label: "Número de expediente", extract: /expediente\s*(?:n[úu]m(?:ero)?\.?|no\.?)?\s*[:#]?\s*(\d[\w\/-]*)/i },
    "escritura" => { label: "Número de escritura", extract: /escritura\s*(?:p[úu]blica)?\s*(?:n[úu]mero|no\.?|#)?\s*(\d[\d,.]*\d|\d)/i },
    "notaria" => { label: "Notaría pública", extract: /notar[íi]a\s*(?:p[úu]blica)?\s*(?:n[úu]mero|no\.?|#)?\s*(\d+)/i },
    "domicilio" => { label: "Domicilio", extract: /domicilio\s+(?:ubicado\s+|sito\s+)?en\s+(.+?)(?=,?\s*C\.\s?P\.|[;\n]|(?<!\bAv|\bNo|\bCol|\bNúm|\bNum|\bInt|\bExt|\bFracc|\bLic|\bBlvd|\bCalz|\bProl|\bPriv|\bCarr|\bMz|\bLt|\bDepto|\bC)\.\s+[A-ZÁÉÍÓÚ][a-záéíóú]{3,}|\.?\z)/i },
    "codigo_postal" => { label: "Código postal", extract: /\bC\.\s?P\.?\s*(\d{5})\b/,
                         format: /\A\d{5}\z/ }
  }.freeze

  AS_DIGIT = { "O" => "0", "Q" => "0", "D" => "0", "@" => "0", "B" => "8", "I" => "1", "L" => "1", "S" => "5", "Z" => "2", "G" => "6" }.freeze
  AS_LETTER = { "0" => "O", "@" => "O", "8" => "B", "1" => "I", "5" => "S", "2" => "Z", "6" => "G" }.freeze

  def self.keys = FIELDS.keys

  def self.label(key) = FIELDS.dig(key.to_s, :label) || key.to_s.humanize

  # Devuelve { "rfc" => "...", ... } solo con los campos encontrados.
  def self.extract(text)
    normalized = text.to_s.gsub(/\r\n?/, "\n")
    FIELDS.each_with_object({}) do |(key, spec), found|
      value = normalized[spec[:extract], 1]&.squish || repaired(normalized, spec)
      found[key] = value if value.present?
    end
  end

  def self.repaired(text, spec)
    token = spec[:labeled] && text[spec[:labeled], 1]
    return unless token

    fixed = token.chars.zip(spec[:layout].call(token).chars).map do |char, kind|
      case kind
      when "D" then AS_DIGIT.fetch(char, char)
      when "L" then AS_LETTER.fetch(char, char)
      else char == "@" ? "0" : char
      end
    end.join
    fixed if fixed.match?(spec[:format])
  end
  private_class_method :repaired

  # Devuelve { "rfc" => "mensaje" } para los valores presentes con formato inválido.
  def self.invalid(values)
    values.to_h.each_with_object({}) do |(key, value), errors|
      format = FIELDS.dig(key.to_s, :format)
      next if format.nil? || value.blank?
      errors[key.to_s] = "#{label(key)} con formato inválido: #{value}" unless value.to_s.strip.match?(format)
    end
  end
end
