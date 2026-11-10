require "test_helper"

class TemplateFillerTest < ActiveSupport::TestCase
  test "fills placeholders using field mappings and marks missing ones" do
    result = TemplateFiller.call(templates(:lease), documents(:lease))

    assert_equal "Arrendador JUAN PEREZ LOPEZ con RFC PELJ800101AB1 paga $12,500.00 el [FECHA].", result.text
    assert_equal %w[fecha], result.missing
    assert_not result.complete?
  end

  test "reports invalid data used in the template" do
    document = documents(:lease)
    document.metadata = document.metadata.merge("rfc" => "MAL", "fecha" => "01/02/2026")

    result = TemplateFiller.call(templates(:lease), document)

    assert_empty result.missing
    assert_equal 1, result.invalid.size
  end

  test "is complete when every placeholder has valid data" do
    document = documents(:lease)
    document.metadata = document.metadata.merge("fecha" => "01/02/2026")

    assert TemplateFiller.call(templates(:lease), document).complete?
  end

  test "fills the original docx preserving formatting, split runs, headers and escaping" do
    template = attach_docx(build_docx)
    document = documents(:lease)
    document.metadata = document.metadata.merge("nombre" => "Pérez & <Hijos>")

    entries = read_docx(TemplateFiller.docx(template, document))

    body = entries["word/document.xml"]
    assert_includes body, %(<w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">Hola Pérez &amp; &lt;Hijos&gt;</w:t></w:r>)
    assert_includes body, %(<w:t xml:space="preserve">, renta $12,500.00</w:t>)
    assert_includes body, "[FECHA]"
    assert_includes body, "<w:t>Sin marcadores</w:t>"
    assert_no_match "{{", body
    assert_includes entries["word/header1.xml"], "Encabezado Pérez &amp; &lt;Hijos&gt;"
    assert_equal "binario", entries["word/media/logo.bin"]
  end

  test "docx returns nil when the template has no Word file" do
    assert_nil TemplateFiller.docx(templates(:lease), documents(:lease))
  end

  test "parts without placeholders are left byte for byte unchanged" do
    entries = read_docx(TemplateFiller.docx(attach_docx(build_docx), documents(:lease)))

    assert_equal FOOTER, entries["word/footer1.xml"]
  end

  test "docx returns nil and call still works for a corrupt file with the docx content type" do
    template = attach_docx("esto no es un zip")

    assert_nil TemplateFiller.docx(template, documents(:lease))
    assert_equal %w[fecha], TemplateFiller.call(template, documents(:lease)).missing
  end

  test "docx returns nil when the xml is not well formed" do
    template = attach_docx(docx_with("word/document.xml" => %(<w:document xmlns:w="#{NS}"><w:p>)))

    assert_nil TemplateFiller.docx(template, documents(:lease))
  end

  test "docx returns nil when the zip has too many entries" do
    parts = (0..TemplateFiller::MAX_DOCX_ENTRIES).to_h { |index| [ "word/media/#{index}.bin", "x" ] }
    template = attach_docx(docx_with(parts))

    assert_nil TemplateFiller.docx(template, documents(:lease))
  end

  test "docx returns nil when a highly compressible entry exceeds the uncompressed limit" do
    template = attach_docx(docx_with("word/media/big.bin" => "a" * 200_000))

    assert_nil TemplateFiller.new(template, documents(:lease), max_uncompressed: 10_000).filled_docx
    assert_not_nil TemplateFiller.new(template, documents(:lease)).filled_docx
  end

  test "docx returns nil when the real inflated size exceeds the limit despite small declared sizes" do
    data = docx_with("word/media/big.bin" => "a" * 200_000)
    central = data.rindex("PK\x01\x02".b)
    data = data.b
    data[central + 24, 4] = [ 10 ].pack("V")
    template = attach_docx(data)

    assert_nil TemplateFiller.new(template, documents(:lease), max_uncompressed: 10_000).filled_docx
  end

  test "docx returns nil for corrupt deflate data and call still works" do
    data = docx_with("word/document.xml" => paragraphs("Hola {{nombre}} " * 20)).b
    name_length, extra_length = data[26, 4].unpack("vv")
    start = 30 + name_length + extra_length
    data[start, 8] = data[start, 8].bytes.map { |byte| byte ^ 0xFF }.pack("C*")
    template = attach_docx(data)

    assert_nil TemplateFiller.docx(template, documents(:lease))
    assert_equal %w[fecha], TemplateFiller.call(template, documents(:lease)).missing
  end

  test "placeholders only in a docx header count as missing" do
    document = documents(:lease)
    document.metadata = document.metadata.merge("fecha" => "01/02/2026")
    body_only = TemplateFiller.call(templates(:lease), document)
    assert body_only.complete?

    template = attach_docx(docx_with(
      "word/document.xml" => paragraphs("Hola {{nombre}}"),
      "word/header1.xml" => %(<w:hdr xmlns:w="#{NS}">#{paragraphs("Tel {{telefono}}", wrap: false)}</w:hdr>)
    ))
    result = TemplateFiller.call(template, document)

    assert_includes result.missing, "telefono"
    assert_not result.complete?
  end

  test "control characters are removed so the xml stays parseable and newlines become spaces" do
    document = documents(:lease)
    document.metadata = document.metadata.merge("nombre" => "A\u0001B\u000bC\nD")
    template = attach_docx(docx_with("word/document.xml" => paragraphs("Hola {{nombre}}")))

    xml = read_docx(TemplateFiller.docx(template, document))["word/document.xml"]

    parsed = Nokogiri::XML(xml) { |config| config.strict }
    assert_equal "Hola ABC D", parsed.at_xpath("//w:t", OcrExtractor::WORD_NS).text
  end

  test "text box paragraphs nested in a paragraph are filled on their own" do
    body = %(<w:p><w:r><w:t>Hola {{nom</w:t></w:r><w:r><w:pict><w:txbxContent>) +
      %(<w:p><w:r><w:t>Caja {{renta}}</w:t></w:r></w:p></w:txbxContent></w:pict></w:r><w:r><w:t>bre}} fin</w:t></w:r></w:p>)
    template = attach_docx(docx_with("word/document.xml" => %(<w:document xmlns:w="#{NS}"><w:body>#{body}</w:body></w:document>)))

    xml = read_docx(TemplateFiller.docx(template, documents(:lease)))["word/document.xml"]

    texts = Nokogiri::XML(xml).xpath("//w:t", OcrExtractor::WORD_NS).map(&:text)
    assert_equal [ "Hola JUAN PEREZ LOPEZ", "Caja $12,500.00", " fin" ], texts
  end

  test "existing escaped text next to a placeholder is preserved" do
    template = attach_docx(docx_with("word/document.xml" => paragraphs("Pérez &amp; Hijos {{nombre}}")))

    xml = read_docx(TemplateFiller.docx(template, documents(:lease)))["word/document.xml"]

    assert_includes xml, "Pérez &amp; Hijos JUAN PEREZ LOPEZ"
    assert_no_match "&amp;amp;", xml
  end

  test "footnotes and endnotes are filled" do
    note = %(<w:footnotes xmlns:w="#{NS}">#{paragraphs("Nota {{nombre}}", wrap: false)}</w:footnotes>)
    template = attach_docx(docx_with("word/document.xml" => paragraphs("x"), "word/footnotes.xml" => note,
                                     "word/endnotes.xml" => note.gsub("footnotes", "endnotes")))

    entries = read_docx(TemplateFiller.docx(template, documents(:lease)))

    assert_includes entries["word/footnotes.xml"], "Nota JUAN PEREZ LOPEZ"
    assert_includes entries["word/endnotes.xml"], "Nota JUAN PEREZ LOPEZ"
  end

  private

  NS = OcrExtractor::WORD_NS["w"]
  FOOTER = %(<w:ftr xmlns:w="#{NS}">  <w:p><w:r><w:t>Pie  de página</w:t></w:r></w:p>\n</w:ftr>)

  def attach_docx(data)
    template = templates(:lease)
    template.file.attach(io: StringIO.new(data), filename: "plantilla.docx", content_type: OcrExtractor::DOCX)
    template
  end

  def paragraphs(text, wrap: true)
    xml = %(<w:p><w:r><w:t>#{text}</w:t></w:r></w:p>)
    wrap ? %(<w:document xmlns:w="#{NS}"><w:body>#{xml}</w:body></w:document>) : xml
  end

  def docx_with(parts)
    Zip::OutputStream.write_buffer(StringIO.new) do |zip|
      parts.each do |name, content|
        zip.put_next_entry(name)
        zip.write(content)
      end
    end.string
  end

  def build_docx
    docx_with(
      "word/document.xml" => %(<w:document xmlns:w="#{NS}"><w:body>) +
        %(<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Hola {{</w:t></w:r><w:r><w:t>nom</w:t></w:r><w:r><w:t>bre}}, renta {{renta}}</w:t></w:r><w:r><w:t>.</w:t></w:r></w:p>) +
        %(<w:p><w:r><w:t>Sin marcadores</w:t></w:r></w:p><w:p><w:r><w:t>{{fecha}}</w:t></w:r></w:p></w:body></w:document>),
      "word/header1.xml" => %(<w:hdr xmlns:w="#{NS}"><w:p><w:r><w:t>Encabezado {{nombre}}</w:t></w:r></w:p></w:hdr>),
      "word/footer1.xml" => FOOTER,
      "word/media/logo.bin" => "binario"
    )
  end

  def read_docx(data)
    zip = Zip::File.open_buffer(StringIO.new(data))
    zip.entries.to_h { |entry| [ entry.name, entry.get_input_stream.read.force_encoding("UTF-8") ] }
  end
end
