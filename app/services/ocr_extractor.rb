require "open3"

# Convierte un archivo (PDF, imagen, Word o texto) en texto plano (RF-01).
# Usa la capa de texto del PDF cuando existe y Tesseract cuando es escaneado.
class OcrExtractor
  class Error < StandardError; end

  MAX_PDF_PAGES = 30
  MIN_TEXT_LAYER_CHARS = 20
  DOCX = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  WORD_NS = { "w" => "http://schemas.openxmlformats.org/wordprocessingml/2006/main" }.freeze

  def self.call(path, content_type)
    case content_type.to_s
    when "application/pdf" then pdf(path)
    when %r{\Aimage/} then tesseract(path)
    when DOCX then docx(path)
    when %r{\Atext/} then File.read(path, encoding: "UTF-8").scrub
    else raise Error, "Formato no soportado para OCR: #{content_type.presence || 'desconocido'}"
    end
  end

  def self.pdf(path)
    text = run("pdftotext", "-layout", "-l", MAX_PDF_PAGES.to_s, path.to_s, "-")
    return text if text.strip.length >= MIN_TEXT_LAYER_CHARS

    Dir.mktmpdir("ocr") do |dir|
      run("pdftoppm", "-r", "300", "-l", MAX_PDF_PAGES.to_s, "-png", path.to_s, File.join(dir, "page"))
      Dir[File.join(dir, "page*.png")].sort.map { |page| tesseract(page) }.join("\n\f")
    end
  end

  def self.tesseract(path)
    run("tesseract", path.to_s, "stdout", "-l", language)
  end

  def self.docx(path)
    xml = run("unzip", "-p", path.to_s, "word/document.xml")
    Nokogiri::XML(xml).xpath("//w:p", WORD_NS)
            .map { |paragraph| paragraph.xpath(".//w:t", WORD_NS).map(&:text).join }
            .join("\n")
  end

  # Español si está instalado (paquete tesseract-data-spa); si no, el primer idioma disponible.
  def self.language
    @language ||= ENV["OCR_LANG"].presence || begin
      available = run("tesseract", "--list-langs").lines.drop(1).map(&:strip) - [ "osd" ]
      (%w[spa eng] & available).first || available.first || raise(Error, "Tesseract no tiene idiomas instalados")
    end
  end

  def self.run(*command)
    stdout, stderr, status = Open3.capture3(*command)
    raise Error, "#{command.first} falló: #{stderr.strip.lines.last}" unless status.success?
    stdout.force_encoding("UTF-8").scrub
  rescue Errno::ENOENT
    raise Error, "Herramienta no instalada en el servidor: #{command.first}"
  end
end
