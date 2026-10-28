require "prawn"
require "rqrcode"
require "zip"

# Exporta el texto autollenado a PDF y Word (.docx) nativos.
module DocumentExport
  DOCX = "application/vnd.openxmlformats-officedocument.wordprocessingml.document".freeze

  Prawn::Fonts::AFM.hide_m17n_warning = true

  module_function

  # verification: { url:, folio: } agrega el pie con QR para validar el documento (RF-03).
  def pdf(text, title:, verification: nil)
    Prawn::Document.new(page_size: "LETTER", margin: [ 72, 72, verification ? 130 : 72, 72 ], info: { Title: pdf_safe(title) }) do |pdf|
      pdf.font "Times-Roman", size: 12
      pdf.text pdf_safe(text), leading: 4, align: :justify
      add_verification_footer(pdf, verification) if verification
    end.render
  end

  def docx(text)
    paragraphs = text.to_s.split("\n", -1).map do |line|
      %(<w:p><w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:sz w:val="24"/></w:rPr><w:t xml:space="preserve">#{ERB::Util.html_escape(line)}</w:t></w:r></w:p>)
    end

    Zip::OutputStream.write_buffer(StringIO.new) do |zip|
      {
        "[Content_Types].xml" => <<~XML,
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
          </Types>
        XML
        "_rels/.rels" => <<~XML,
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
          </Relationships>
        XML
        "word/document.xml" => <<~XML
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>#{paragraphs.join}</w:body></w:document>
        XML
      }.each do |name, content|
        zip.put_next_entry(name)
        zip.write(content)
      end
    end.string
  end

  def add_verification_footer(pdf, verification)
    qr = RQRCode::QRCode.new(verification[:url]).as_png(size: 240, border_modules: 1).to_blob
    lines = [
      { text: "Documento emitido con DigitalLaw. Verifique su autenticidad escaneando el código QR o en:\n" },
      { text: "#{verification[:url]}\n", color: "1D4ED8" },
      { text: "Folio: #{verification[:folio]}\n" },
      { text: "La huella SHA-256 de este archivo se conserva en el servidor; cualquier alteración invalida la verificación.", color: "555555" }
    ]

    # El pie va en el margen inferior; text_box no pagina aunque quede fuera del área de contenido.
    (1..pdf.page_count).each do |page|
      pdf.go_to_page(page)
      pdf.stroke_horizontal_line 0, pdf.bounds.width, at: -20
      pdf.image StringIO.new(qr), at: [ 0, -26 ], width: 75
      pdf.formatted_text_box lines, at: [ 90, -28 ], width: pdf.bounds.width - 90, height: 75, size: 8, leading: 2
    end
  end

  # Las fuentes PDF integradas solo admiten Windows-1252.
  def pdf_safe(text)
    text.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?").encode("UTF-8")
  end
end
