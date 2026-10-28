require "test_helper"

class Api::V1::DocumentsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { @headers = { "Authorization" => "Bearer #{users(:one).regenerate_api_token!}" } }

  test "requires a valid token" do
    get api_v1_documents_path, headers: { "Authorization" => "Bearer malo" }

    assert_response :unauthorized
  end

  test "lists and filters only the firm's documents" do
    get api_v1_documents_path, params: { procedure_type: "Arrendamiento" }, headers: @headers

    titles = response.parsed_body["documents"].pluck("title")
    assert_equal [ "Arrendamiento Pérez" ], titles
  end

  test "shows a document and logs the access" do
    get api_v1_document_path(documents(:lease)), headers: @headers

    assert_equal "PELJ800101AB1", response.parsed_body.dig("metadata", "rfc")
    assert_equal [ "access", users(:one).id.to_s ], documents(:lease).versions.last.slice(:event, :whodunnit).values
  end

  test "cannot read another firm's document" do
    get api_v1_document_path(documents(:other_firm)), headers: @headers

    assert_response :not_found
  end

  test "creates a document with a file and queues OCR" do
    assert_enqueued_jobs 1, only: DocumentOcrJob do
      post api_v1_documents_path, headers: @headers, params: {
        document: { title: "Desde CRM", file: fixture_file_upload("contrato.txt", "text/plain") }
      }
    end

    assert_response :created
    assert_equal "processing", response.parsed_body["status"]
  end

  test "rejects invalid documents" do
    post api_v1_documents_path, headers: @headers, params: { document: { title: "" } }, as: :json

    assert_response :unprocessable_entity
  end

  test "merges metadata on update" do
    patch api_v1_document_path(documents(:lease)), headers: @headers, as: :json,
          params: { document: { metadata: { "fecha" => "01/02/2026", "monto" => "" } } }

    assert_response :success
    assert_equal({ "nombre" => "JUAN PEREZ LOPEZ", "rfc" => "PELJ800101AB1", "fecha" => "01/02/2026" }, documents(:lease).reload.metadata)
  end

  test "autofills a template" do
    get fill_api_v1_document_path(documents(:lease)), params: { template_id: templates(:lease).id }, headers: @headers

    body = response.parsed_body
    assert_equal [ "fecha" ], body["missing"]
    assert_not body["complete"]
  end

  test "lists available templates" do
    get api_v1_templates_path, headers: @headers

    assert_equal [ "Arrendamiento del despacho", "Carta poder (biblioteca)" ], response.parsed_body.pluck("name")
  end
end
