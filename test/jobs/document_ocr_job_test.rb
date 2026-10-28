require "test_helper"

class DocumentOcrJobTest < ActiveJob::TestCase
  test "stores text and detected data without overwriting manual data" do
    document = documents(:lease)
    document.file.attach(io: file_fixture("contrato.txt").open, filename: "contrato.txt", content_type: "text/plain")
    document.update!(metadata: { "nombre" => "Nombre corregido a mano" })

    DocumentOcrJob.perform_now(document)

    document.reload
    assert document.completed?
    assert_includes document.extracted_text, "ARRENDAMIENTO"
    assert_equal "Nombre corregido a mano", document.metadata["nombre"]
    assert_equal "PELJ800101AB1", document.metadata["rfc"]
  end

  test "marks the document with error when OCR fails" do
    document = documents(:power)
    document.file.attach(io: StringIO.new("x"), filename: "a.txt", content_type: "text/plain")
    document.file.blob.update!(content_type: "application/octet-stream")

    DocumentOcrJob.perform_now(document)

    assert document.reload.error?
    assert_match "no soportado", document.ocr_error
  end
end
