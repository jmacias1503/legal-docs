require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { sign_in users(:one) }

  test "requires login" do
    sign_out :user
    get documents_path

    assert_redirected_to new_user_session_path
  end

  test "lists only documents of the user's firm" do
    get documents_path

    assert_response :success
    assert_match "Arrendamiento Pérez", response.body
    assert_no_match "Expediente ajeno", response.body
  end

  test "filters the list" do
    get documents_path, params: { procedure_type: "Poder notarial" }

    assert_match "Poder Gómez", response.body
    assert_no_match "Arrendamiento Pérez", response.body
  end

  test "cannot access documents from another firm" do
    get document_path(documents(:other_firm))

    assert_response :not_found
  end

  test "creates a document and queues OCR for the uploaded file" do
    assert_enqueued_jobs 1, only: DocumentOcrJob do
      post documents_path, params: { document: { title: "Nuevo", client: "Cliente", file: fixture_file_upload("contrato.txt", "text/plain") } }
    end

    document = Document.order(:id).last
    assert_redirected_to document
    assert_equal users(:one), document.user
    assert_equal firms(:one), document.firm
    assert document.processing?
  end

  test "rejects invalid documents" do
    post documents_path, params: { document: { title: "" } }

    assert_response :unprocessable_entity
  end

  test "updates, normalizes and removes metadata fields" do
    patch document_path(documents(:lease)), params: { document: {
      title: "Arrendamiento Pérez", metadata: { "nombre" => "JUAN PEREZ", "rfc" => "", "monto" => "$12,500.00" },
      new_field_key: "Precio Renta", new_field_value: "$10,000.00"
    } }

    metadata = documents(:lease).reload.metadata
    assert_equal({ "nombre" => "JUAN PEREZ", "monto" => "$12,500.00", "precio_renta" => "$10,000.00" }, metadata)
  end

  test "records audit trail with the acting user" do
    patch document_path(documents(:power)), params: { document: { title: "Poder actualizado" } }

    assert_equal users(:one).id.to_s, documents(:power).versions.last.whodunnit
  end

  test "validates data only when formats are correct" do
    patch confirm_document_path(documents(:lease))
    assert documents(:lease).reload.validated?

    documents(:power).update!(status: :completed, metadata: { "rfc" => "MAL" })
    patch confirm_document_path(documents(:power))
    assert documents(:power).reload.completed?
    assert_match "RFC", flash[:alert]
  end

  test "reprocess requires an attached file" do
    post reprocess_document_path(documents(:power))

    assert_equal "El documento no tiene archivo.", flash[:alert]
  end

  test "previews and downloads autofilled document" do
    get fill_document_path(documents(:lease), template_id: templates(:lease).id)
    assert_response :success
    assert_match "JUAN PEREZ LOPEZ", response.body
    assert_match "Campos faltantes", response.body

    get fill_document_path(documents(:lease), template_id: templates(:library).id, format: :text)
    assert_equal "Yo, JUAN PEREZ LOPEZ, otorgo poder.", response.body
  end

  test "cannot autofill with another firm's template" do
    get fill_document_path(documents(:lease), template_id: templates(:other_firm).id)

    assert_response :not_found
  end

  test "shows document detail with audit history" do
    get document_path(documents(:lease))

    assert_response :success
    assert_match "Historial de auditoría", response.body
  end

  test "destroys a document" do
    assert_difference("Document.count", -1) { delete document_path(documents(:power)) }
  end

  test "viewing a document is recorded in the audit log" do
    assert_difference -> { documents(:lease).versions.where(event: "access").count }, 1 do
      get document_path(documents(:lease))
    end
  end

  test "validation is recorded as its own audit event" do
    patch confirm_document_path(documents(:lease))

    assert_equal "validate", documents(:lease).versions.last.event
  end

  test "downloads autofilled document as PDF and Word" do
    get fill_document_path(documents(:lease), template_id: templates(:library).id, format: :pdf)
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")

    get fill_document_path(documents(:lease), template_id: templates(:library).id, format: :docx)
    assert_equal DocumentExport::DOCX, response.media_type
    assert response.body.start_with?("PK")
    assert_equal "download", documents(:lease).versions.last.event
  end

  test "issues a sealed PDF whose hash can be verified publicly" do
    assert_difference("IssuedDocument.count", 1) do
      post issue_document_path(documents(:lease), template_id: templates(:library).id)
    end
    issued = IssuedDocument.last
    pdf = issued.file.download
    assert_equal Digest::SHA256.hexdigest(pdf), issued.sha256
    assert_equal "issue", documents(:lease).versions.last.event

    sign_out :user
    get verification_path(issued.token)
    assert_response :success
    assert_match issued.sha256, response.body
    assert_no_match "Juan Pérez", response.body

    post verification_path(issued.token), params: { file: Rack::Test::UploadedFile.new(StringIO.new(pdf), "application/pdf", original_filename: "a.pdf") }
    assert_match "no ha sido alterado", response.body

    post verification_path(issued.token), params: { file: Rack::Test::UploadedFile.new(StringIO.new(pdf + "x"), "application/pdf", original_filename: "a.pdf") }
    assert_match "NO coincide", response.body
  end

  test "does not issue documents with missing data" do
    assert_no_difference("IssuedDocument.count") do
      post issue_document_path(documents(:lease), template_id: templates(:lease).id)
    end
    assert_match "Completa", flash[:alert]
  end

  test "unknown verification folio returns not found" do
    sign_out :user
    get verification_path("inexistente")

    assert_response :not_found
    assert_match "No existe", response.body
  end
end
