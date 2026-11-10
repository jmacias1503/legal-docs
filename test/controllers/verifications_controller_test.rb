require "test_helper"

# RNF-01: la verificación pública no debe leer archivos de tamaño arbitrario.
class VerificationsControllerTest < ActionDispatch::IntegrationTest
  PDF = "%PDF-1.4 contenido de prueba".b.freeze

  setup do
    @issued = documents(:lease).issued_documents.create!(
      template_name: "Contrato de arrendamiento", sha256: Digest::SHA256.hexdigest(PDF)
    )
  end

  test "file under the limit is verified" do
    post verification_path(@issued.token), params: { file: upload(PDF) }
    assert_response :success
    assert_match "no ha sido alterado", response.body

    post verification_path(@issued.token), params: { file: upload(PDF + "x") }
    assert_response :success
    assert_match "NO coincide", response.body
  end

  test "file over the limit is rejected without being compared" do
    with_max_upload_bytes(10) do
      post verification_path(@issued.token), params: { file: upload("a" * 100) }
      assert_response :unprocessable_entity
      assert_match "demasiado grande (máximo 10 Bytes)", response.body
      assert_no_match "no ha sido alterado", response.body
      assert_no_match "NO coincide", response.body

      post verification_path(@issued.token), params: { file: upload("a" * 10) }
      assert_response :success
      assert_match "NO coincide", response.body
    end
  end

  test "missing file shows a friendly message" do
    post verification_path(@issued.token)
    assert_response :unprocessable_entity
    assert_match "Selecciona un archivo PDF", response.body
  end

  test "non-file params do not raise" do
    post verification_path(@issued.token), params: { file: "x" }
    assert_response :unprocessable_entity
    assert_match "Selecciona un archivo PDF", response.body

    post verification_path(@issued.token), params: { file: [ "x" ] }
    assert_response :unprocessable_entity
    assert_match "Selecciona un archivo PDF", response.body

    post verification_path(@issued.token), params: { file: { x: "y" } }
    assert_response :unprocessable_entity
    assert_match "Selecciona un archivo PDF", response.body
  end

  test "unknown token is not found" do
    post verification_path("token-inexistente"), params: { file: upload(PDF) }
    assert_response :not_found
  end

  private

  def upload(content)
    tempfile = Tempfile.new([ "verificacion", ".pdf" ], binmode: true)
    tempfile.write(content)
    tempfile.rewind
    (@tempfiles ||= []) << tempfile
    Rack::Test::UploadedFile.new(tempfile.path, "application/pdf", true)
  end

  def with_max_upload_bytes(limit)
    original = VerificationsController.max_upload_bytes
    VerificationsController.max_upload_bytes = limit
    yield
  ensure
    VerificationsController.max_upload_bytes = original
  end
end
