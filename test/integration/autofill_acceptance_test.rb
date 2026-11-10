require "test_helper"

# Pruebas de aceptación del módulo 2 (autollenado, RF-02) con las plantillas de la biblioteca legal.
class AutofillAcceptanceTest < ActionDispatch::IntegrationTest
  COMPLETE_METADATA = {
    "nombre" => "MARIA GOMEZ RUIZ", "contraparte" => "PEDRO LOPEZ DIAZ",
    "rfc" => "GORM800101AB1", "curp" => "GORM800101MQTMZR09",
    "domicilio" => "Av. Reforma 10, Col. Centro", "codigo_postal" => "76000",
    "monto" => "$8,500.00", "fecha" => "01/02/2026", "expediente" => "123/2026"
  }.freeze

  setup do
    # db/seeds.rb define la constante LIBRARY; se descarta para poder cargarlo en cada prueba.
    Object.send(:remove_const, :LIBRARY) if Object.const_defined?(:LIBRARY)
    load Rails.root.join("db/seeds.rb")

    @lease_template = Template.library.find_by!(name: "Contrato de arrendamiento")
    @power_template = Template.library.find_by!(name: "Carta poder simple")
    @motion_template = Template.library.find_by!(name: "Escrito de promoción en expediente")
    @user = users(:one)
    @document = complete_document
    sign_in @user
  end

  test "complete document fills every library template without leftover markers" do
    [ @lease_template, @power_template, @motion_template ].each do |template|
      get fill_document_path(@document, template_id: template.id)
      assert_response :success
      assert_match "MARIA GOMEZ RUIZ", response.body
      assert_no_match(/\[[A-Z_]+\]/, response.body, template.name)
      assert_no_match "Campos faltantes", response.body
      assert_no_match "{{", response.body
      assert_match "Emitir con sello", response.body

      get fill_document_path(@document, template_id: template.id, format: :text)
      assert_response :success
      assert_match "MARIA GOMEZ RUIZ", response.body
      assert_no_match(/\[[A-Z_]+\]|\{\{/, response.body, template.name)
    end

    get fill_document_path(@document, template_id: @lease_template.id, format: :text)
    assert_includes response.body, "PEDRO LOPEZ DIAZ"
    assert_includes response.body, "$8,500.00"
    assert_includes response.body, "Av. Reforma 10, Col. Centro"
    assert_includes response.body, I18n.l(Date.current, format: "%d/%m/%Y")

    get fill_document_path(@document, template_id: @power_template.id, format: :text)
    assert_includes response.body, "GORM800101MQTMZR09"
    assert_includes response.body, "Arrendamiento"

    get fill_document_path(@document, template_id: @motion_template.id, format: :text)
    assert_includes response.body, "EXPEDIENTE: 123/2026"
    assert_includes response.body, "María Gómez"
  end

  test "downloads every library template as txt, pdf and docx" do
    [ @lease_template, @power_template, @motion_template ].each do |template|
      get fill_document_path(@document, template_id: template.id, format: :text)
      assert_equal "text/plain", response.media_type
      assert_includes response.body, "MARIA GOMEZ RUIZ"

      get fill_document_path(@document, template_id: template.id, format: :pdf)
      assert_equal "application/pdf", response.media_type
      assert response.body.start_with?("%PDF"), "PDF inválido para #{template.name}"

      get fill_document_path(@document, template_id: template.id, format: :docx)
      assert_equal DocumentExport::DOCX, response.media_type
      assert_includes docx_xml(response.body), "MARIA GOMEZ RUIZ"
      assert_no_match(/\[[A-Z_]+\]|\{\{/, docx_xml(response.body))
    end
  end

  test "document with missing data shows markers and a warning, and cannot be issued" do
    incomplete = create_document(metadata: { "nombre" => "MARIA GOMEZ RUIZ" })

    get fill_document_path(incomplete, template_id: @lease_template.id)
    assert_response :success
    assert_match "MARIA GOMEZ RUIZ", response.body
    assert_match "[RFC]", response.body
    assert_match "[DOMICILIO]", response.body
    assert_match "Campos faltantes", response.body
    assert_no_match "Emitir con sello", response.body

    get fill_document_path(incomplete, template_id: @lease_template.id, format: :text)
    assert_includes response.body, "[CONTRAPARTE]"

    assert_no_difference("IssuedDocument.count") do
      post issue_document_path(incomplete, template_id: @lease_template.id)
    end
    assert_redirected_to fill_document_path(incomplete, template_id: @lease_template.id)
    assert_match "Completa", flash[:alert]
  end

  test "invalid RFC or CURP shows a warning and blocks issuing" do
    { "rfc" => "MAL", "curp" => "NOESCURP" }.each do |field, bad_value|
      template = field == "rfc" ? @lease_template : @power_template
      document = create_document(metadata: COMPLETE_METADATA.merge(field => bad_value))

      get fill_document_path(document, template_id: template.id)
      assert_response :success
      assert_match "#{field.upcase} con formato inválido: #{bad_value}", response.body
      assert_no_match "Emitir con sello", response.body

      assert_no_difference("IssuedDocument.count") do
        post issue_document_path(document, template_id: template.id)
      end
      assert_redirected_to fill_document_path(document, template_id: template.id)
    end
  end

  test "firm template with field mappings takes values from the mapped field" do
    template = firms(:one).templates.create!(
      name: "Mapeada", body: "Renta de {{renta}} a cargo de {{inquilino}}.",
      field_mappings: { "renta" => "monto", "inquilino" => "contraparte" }
    )

    get fill_document_path(@document, template_id: template.id, format: :text)
    assert_equal "Renta de $8,500.00 a cargo de PEDRO LOPEZ DIAZ.", response.body

    @document.update!(metadata: @document.metadata.except("monto"))
    get fill_document_path(@document, template_id: template.id)
    assert_match "[RENTA]", response.body
    assert_match "Campos faltantes", response.body
  end

  test "firm Word template downloads the filled original keeping formatting" do
    template = firms(:one).templates.create!(name: "Word del despacho", body: "Yo {{nombre}}, RFC {{rfc}}.")
    template.file.attach(io: StringIO.new(build_docx), filename: "plantilla.docx", content_type: OcrExtractor::DOCX)

    get fill_document_path(@document, template_id: template.id, format: :docx)
    assert_response :success
    assert_equal DocumentExport::DOCX, response.media_type
    xml = docx_xml(response.body)
    assert_includes xml, "<w:b/>"
    assert_includes xml, "MARIA GOMEZ RUIZ"
    assert_includes xml, "GORM800101AB1"
    assert_no_match "{{", xml
    assert_no_match(/\[[A-Z_]+\]/, xml)
    assert_includes xml, "Texto fijo"

    # El valor queda en el run donde empieza el marcador, que conserva sus negritas.
    bold_run = Nokogiri::XML(xml).at_xpath("//w:r[w:rPr/w:b]", OcrExtractor::WORD_NS)
    assert bold_run, "se perdió el run en negritas"
    assert bold_run.at_xpath("w:t", OcrExtractor::WORD_NS).text.start_with?("Yo MARIA GOMEZ RUIZ")

    get fill_document_path(@document, template_id: template.id, format: :text)
    assert_equal "Yo MARIA GOMEZ RUIZ, RFC GORM800101AB1.", response.body

    get fill_document_path(@document, template_id: template.id, format: :pdf)
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")
  end

  test "values with XML special characters are escaped in the filled Word" do
    document = create_document(metadata: COMPLETE_METADATA.merge("nombre" => "PÉREZ & <HIJOS>"))
    template = firms(:one).templates.create!(name: "Word especial", body: "Yo {{nombre}}, RFC {{rfc}}.")
    template.file.attach(io: StringIO.new(build_docx), filename: "plantilla.docx", content_type: OcrExtractor::DOCX)

    get fill_document_path(document, template_id: template.id, format: :docx)
    assert_response :success
    xml = docx_xml(response.body)
    parsed = Nokogiri::XML(xml) { |config| config.strict }
    assert_includes xml, "PÉREZ &amp; &lt;HIJOS&gt;"
    assert_includes parsed.xpath("//w:t", OcrExtractor::WORD_NS).map(&:text).join, "Yo PÉREZ & <HIJOS>, RFC GORM800101AB1."
  end

  test "a placeholder only present in the firm Word file blocks issuing" do
    template = firms(:one).templates.create!(name: "Word con extra", body: "Yo {{nombre}}.")
    template.file.attach(io: StringIO.new(build_docx(extra: "Expediente {{expediente}}")),
                         filename: "plantilla.docx", content_type: OcrExtractor::DOCX)
    @document.update!(metadata: @document.metadata.except("expediente"))

    get fill_document_path(@document, template_id: template.id)
    assert_response :success
    assert_match "Campos faltantes", response.body
    assert_match LegalFields.label("expediente"), response.body
    assert_no_match "Emitir con sello", response.body

    assert_no_difference("IssuedDocument.count") do
      post issue_document_path(@document, template_id: template.id)
    end
    assert_redirected_to fill_document_path(@document, template_id: template.id)
  end

  test "a corrupt Word file falls back to the generated Word and still renders" do
    template = firms(:one).templates.create!(name: "Word corrupto", body: "Yo {{nombre}}.")
    template.file.attach(io: StringIO.new("esto no es un zip"), filename: "plantilla.docx", content_type: OcrExtractor::DOCX)

    get fill_document_path(@document, template_id: template.id)
    assert_response :success
    assert_match "MARIA GOMEZ RUIZ", response.body

    get fill_document_path(@document, template_id: template.id, format: :docx)
    assert_response :success
    assert_equal DocumentExport::DOCX, response.media_type
    assert_includes docx_xml(response.body), "MARIA GOMEZ RUIZ"
  end

  test "issues a sealed PDF with token and sha256 that is verifiable without exposing client data" do
    assert_difference("IssuedDocument.count", 1) do
      post issue_document_path(@document, template_id: @lease_template.id)
    end
    assert_redirected_to document_path(@document)

    issued = @document.issued_documents.last
    pdf = issued.file.download
    assert pdf.start_with?("%PDF")
    assert issued.token.present?
    assert_match(/\A\h{64}\z/, issued.sha256)
    assert_equal Digest::SHA256.hexdigest(pdf), issued.sha256
    assert_equal "Contrato de arrendamiento", issued.template_name

    sign_out :user
    get verification_path(issued.token)
    assert_response :success
    assert_match "Despacho Uno", response.body
    assert_match "Contrato de arrendamiento", response.body
    assert_match issued.sha256, response.body
    assert_match I18n.l(issued.created_at, format: "%d/%m/%Y"), response.body
    private_data_list.each { |private_data| assert_no_match private_data, response.body }

    post verification_path(issued.token), params: { file: upload(pdf) }
    assert_match "no ha sido alterado", response.body
    private_data_list.each { |private_data| assert_no_match private_data, response.body }

    post verification_path(issued.token), params: { file: upload(pdf + "x") }
    assert_match "NO coincide", response.body

    tampered = pdf.dup.b
    middle = tampered.bytesize / 2
    tampered.setbyte(middle, tampered.getbyte(middle) ^ 0xFF)
    post verification_path(issued.token), params: { file: upload(tampered) }
    assert_match "NO coincide", response.body
    assert_no_match "no ha sido alterado", response.body

    get verification_path("token-inexistente")
    assert_response :not_found
    post verification_path("token-inexistente"), params: { file: upload(pdf) }
    assert_response :not_found
  end

  test "a user from another firm cannot fill or see documents and templates of this firm" do
    own_template = firms(:one).templates.create!(name: "Privada", body: "{{nombre}}")
    sign_out :user

    # Los helpers sign_in/sign_out de Devise/Warden encolan su acción solo para la SIGUIENTE
    # petición (on_next_request), por eso se inicia sesión como users(:two) antes de cada una.
    sign_in users(:two)
    get document_path(@document)
    assert_response :not_found

    sign_in users(:two)
    get fill_document_path(@document, template_id: @lease_template.id)
    assert_response :not_found

    sign_in users(:two)
    get fill_document_path(documents(:other_firm), template_id: own_template.id)
    assert_response :not_found

    sign_in users(:two)
    get template_path(own_template)
    assert_response :not_found

    sign_in users(:two)
    assert_no_difference("IssuedDocument.count") do
      post issue_document_path(@document, template_id: @lease_template.id)
    end
    assert_response :not_found

    # La biblioteca sí es visible para todos.
    sign_in users(:two)
    get fill_document_path(documents(:other_firm), template_id: @lease_template.id)
    assert_response :success
  end

  test "a user cannot use a private template of another firm" do
    sign_in @user
    get fill_document_path(@document, template_id: templates(:other_firm).id)
    assert_response :not_found

    sign_in @user
    assert_no_difference("IssuedDocument.count") do
      post issue_document_path(@document, template_id: templates(:other_firm).id)
    end
    assert_response :not_found
  end

  test "unauthenticated requests to fill and issue redirect to sign in" do
    sign_out :user
    get fill_document_path(@document, template_id: @lease_template.id)
    assert_redirected_to new_user_session_path

    assert_no_difference("IssuedDocument.count") do
      post issue_document_path(@document, template_id: @lease_template.id)
    end
    assert_redirected_to new_user_session_path
  end

  test "a field mapping takes precedence over a raw key with the placeholder name" do
    template = firms(:one).templates.create!(
      name: "Mapeada con clave cruda", body: "Renta de {{renta}}.", field_mappings: { "renta" => "monto" }
    )
    @document.update!(metadata: @document.metadata.merge("renta" => "$999.00"))

    get fill_document_path(@document, template_id: template.id, format: :text)
    assert_equal "Renta de $8,500.00.", response.body
  end

  private

  def complete_document = create_document(metadata: COMPLETE_METADATA)

  def create_document(metadata:)
    firms(:one).documents.create!(
      title: "Expediente María Gómez", client: "María Gómez", procedure_type: "Arrendamiento",
      user: @user, status: :validated, metadata:
    )
  end

  def docx_xml(data)
    Zip::File.open_buffer(StringIO.new(data)).read("word/document.xml").force_encoding("UTF-8")
  end

  def private_data_list
    [ "MARIA GOMEZ RUIZ", "GORM800101AB1", "PEDRO LOPEZ DIAZ", "María Gómez", "Av. Reforma" ]
  end

  def upload(content)
    Rack::Test::UploadedFile.new(StringIO.new(content), "application/pdf", original_filename: "documento.pdf")
  end

  # Word con una corrida en negritas y marcadores partidos en varios <w:t>.
  def build_docx(extra: nil)
    ns = OcrExtractor::WORD_NS["w"]
    xml = %(<w:document xmlns:w="#{ns}"><w:body>) +
          %(<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Yo {{nom</w:t></w:r><w:r><w:t>bre}}, RFC {{r</w:t></w:r><w:r><w:t>fc}}.</w:t></w:r></w:p>) +
          %(<w:p><w:r><w:t>Texto fijo</w:t></w:r></w:p>) +
          (extra ? %(<w:p><w:r><w:t>#{extra}</w:t></w:r></w:p>) : "") +
          %(</w:body></w:document>)
    Zip::OutputStream.write_buffer(StringIO.new) do |zip|
      zip.put_next_entry("word/document.xml")
      zip.write xml
    end.string
  end
end
