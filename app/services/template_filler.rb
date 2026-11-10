require "zip"

# Llena una plantilla con los datos de un documento (RF-02).
# Los campos faltantes quedan marcados como [CAMPO] para revisión manual.
class TemplateFiller
  Result = Data.define(:text, :missing, :invalid) do
    def complete? = missing.empty? && invalid.empty?
  end

  class UnsafeDocx < StandardError; end

  DOCX_PARTS = %r{\Aword/(document|header[^/]*|footer[^/]*|footnotes|endnotes)\.xml\z}
  WORD_NS = OcrExtractor::WORD_NS

  # Límites contra zip bombs.
  MAX_DOCX_BYTES = 10.megabytes
  MAX_DOCX_UNCOMPRESSED_BYTES = 50.megabytes
  MAX_DOCX_ENTRIES = 1000

  # Caracteres no permitidos en XML 1.0 (se conservan \t \n \r, que luego se vuelven espacios).
  XML_ILLEGAL = /[^\u0009\u000A\u000D -퟿-�\u{10000}-\u{10FFFF}]/

  DOCX_ERRORS = [
    UnsafeDocx, Zip::Error, Zlib::Error, EOFError, IOError, Nokogiri::XML::SyntaxError, EncodingError,
    ActiveStorage::FileNotFoundError, SystemCallError
  ].freeze

  CHUNK_BYTES = 64.kilobytes

  # Para plantillas con Word adjunto, los marcadores del archivo original también cuentan
  # como faltantes/inválidos, de modo que la validación coincide con lo que se descarga.
  def self.call(template, document)
    filler = new(template, document)
    text = filler.fill(template.body.to_s)
    filler.filled_docx if template.docx_file?
    Result.new(text:, missing: filler.missing.uniq, invalid: filler.invalid)
  end

  # Llena el .docx original de la plantilla conservando su formato. Devuelve el
  # contenido binario del archivo, o nil si la plantilla no tiene un Word adjunto
  # o el archivo no se puede procesar (el llamador usa entonces el texto del cuerpo).
  def self.docx(template, document)
    return unless template.docx_file?

    new(template, document).filled_docx
  end

  attr_reader :missing

  def initialize(template, document, max_uncompressed: MAX_DOCX_UNCOMPRESSED_BYTES)
    @template = template
    @max_uncompressed = max_uncompressed
    @values = document.field_values
    @used = {}
    @missing = []
  end

  def invalid = LegalFields.invalid(@used).values

  # Única lógica de sustitución: cada marcador se resuelve a su valor o a [CAMPO].
  # El bloque opcional transforma el valor (p. ej. limpiarlo para XML).
  def fill(string, &transform)
    string.gsub(Template::PLACEHOLDER) { resolve($1, &transform) }
  end

  # Como fill_docx, pero devuelve nil (y no registra marcadores) si el archivo es inválido o inseguro.
  def filled_docx
    saved = [ @missing.dup, @used.dup ]
    fill_docx(@template.file.download)
  rescue *DOCX_ERRORS => error
    @missing, @used = saved
    Rails.logger.warn("No se pudo llenar el Word de la plantilla #{@template.id}: #{error.class}: #{error.message}")
    nil
  end

  def fill_docx(data)
    raise UnsafeDocx, "archivo demasiado grande" if data.bytesize > MAX_DOCX_BYTES

    @remaining = @max_uncompressed
    output = Zip::OutputStream.write_buffer(StringIO.new) do |out|
      Zip::File.open_buffer(StringIO.new(data)) do |zip|
        check_entries!(zip)
        zip.each do |entry|
          next if entry.directory?

          content = read_entry(entry)
          content = fill_xml(content) if entry.name.match?(DOCX_PARTS)
          out.put_next_entry(entry.name)
          out.write(content)
        end
      end
    end
    output.string
  end

  private

  def resolve(name)
    placeholder = name.downcase
    source = @template.source_for(placeholder)
    value = @values[source]
    if value.present?
      @used[source] = value
    else
      @missing << placeholder
      value = "[#{placeholder.upcase}]"
    end
    block_given? ? yield(value.to_s) : value
  end

  def check_entries!(zip)
    entries = zip.entries
    raise UnsafeDocx, "demasiadas entradas" if entries.size > MAX_DOCX_ENTRIES
    raise UnsafeDocx, "tamaño descomprimido excesivo" if entries.sum(&:size) > @max_uncompressed
  end

  # Los tamaños del encabezado los controla el atacante: se cuenta lo realmente
  # descomprimido, por bloques, contra un presupuesto compartido por todas las entradas.
  def read_entry(entry)
    content = String.new
    entry.get_input_stream do |stream|
      while (chunk = stream.read(CHUNK_BYTES))
        @remaining -= chunk.bytesize
        raise UnsafeDocx, "tamaño descomprimido excesivo" if @remaining.negative?

        content << chunk
      end
    end
    content
  end

  # Solo se reserializa la parte si cambió; las demás pasan byte a byte.
  def fill_xml(content)
    doc = Nokogiri::XML(content) { |config| config.strict.nonet }
    changed = doc.xpath("//w:p", WORD_NS).map { |paragraph| fill_paragraph(paragraph) }.any?
    changed ? doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "UTF-8") : content
  end

  # Word suele partir un marcador en varios <w:t>; se unen los textos propios del párrafo
  # (sin los de párrafos anidados, p. ej. cuadros de texto) y el valor queda en el run
  # donde empieza el marcador (conserva su formato).
  def fill_paragraph(paragraph)
    nodes = paragraph.xpath(".//w:t", WORD_NS).select { |node| node.xpath("ancestor::w:p[1]", WORD_NS).first == paragraph }
    texts = nodes.map(&:text)
    joined = texts.join
    return false unless joined.match?(Template::PLACEHOLDER)

    matches = []
    joined.scan(Template::PLACEHOLDER) do
      match = Regexp.last_match
      matches << [ match.begin(0), match.end(0), resolve(match[1]) { |value| xml_safe(value) } ]
    end

    offset = 0
    nodes.zip(texts) do |node, text|
      range = offset...(offset + text.length)
      offset = range.end
      rebuilt = rebuild_text(joined, range, matches)
      next if rebuilt == text

      node.content = rebuilt
      node["xml:space"] = "preserve"
    end
    true
  end

  # Quita caracteres ilegales en XML y convierte saltos/tabuladores en espacios.
  def xml_safe(value)
    value.scrub("").gsub(XML_ILLEGAL, "").gsub(/[\t\r\n]+/, " ")
  end

  def rebuild_text(joined, range, matches)
    result = +""
    position = range.begin
    matches.each do |from, to, replacement|
      next unless from < range.end && to > range.begin

      overlap_start = [ from, range.begin ].max
      result << joined[position...overlap_start] if overlap_start > position
      result << replacement if from >= range.begin
      position = [ to, range.end ].min
    end
    result << joined[position...range.end] if position < range.end
    result
  end
end
