require "test_helper"

class OcrExtractorTest < ActiveSupport::TestCase
  test "reads plain text files" do
    text = OcrExtractor.call(file_fixture("contrato.txt"), "text/plain")

    assert_includes text, "CONTRATO DE ARRENDAMIENTO"
  end

  test "uses the text layer of PDFs" do
    skip "pdftotext no instalado" unless system("which pdftotext > /dev/null 2>&1")

    text = OcrExtractor.call(file_fixture("contrato.pdf"), "application/pdf")

    assert_includes text, "PELJ800101AB1"
  end

  test "rejects unsupported formats" do
    error = assert_raises(OcrExtractor::Error) { OcrExtractor.call("x.zip", "application/zip") }

    assert_match "no soportado", error.message
  end

  test "reports missing tools" do
    error = assert_raises(OcrExtractor::Error) { OcrExtractor.run("herramienta-inexistente") }

    assert_match "no instalada", error.message
  end
end
