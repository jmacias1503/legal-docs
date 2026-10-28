require "test_helper"

class LegalFieldsTest < ActiveSupport::TestCase
  test "extracts legal data from text" do
    fields = LegalFields.extract(file_fixture("contrato.txt").read)

    assert_equal "JUAN PEREZ LOPEZ", fields["nombre"]
    assert_equal "MARIA GOMEZ RUIZ", fields["contraparte"]
    assert_equal "PELJ800101AB1", fields["rfc"]
    assert_equal "PELJ800101HQTRPN09", fields["curp"]
    assert_equal "15 de octubre de 2026", fields["fecha"]
    assert_equal "$12,500.00", fields["monto"]
    assert_equal "245/2026", fields["expediente"]
    assert_equal "12", fields["notaria"]
    assert_equal "Av. Universidad 100, Centro", fields["domicilio"]
    assert_equal "76000", fields["codigo_postal"]
  end

  test "repairs common OCR confusions in labeled RFC" do
    assert_equal "PELJ800101AB1", LegalFields.extract("con RFC PELJBOO1@1AB1 y")["rfc"]
  end

  test "keeps street abbreviations inside the address" do
    text = "señalando domicilio en Blvd. Bernardo Quintana 4100, C.P. 76090"

    assert_equal "Blvd. Bernardo Quintana 4100", LegalFields.extract(text)["domicilio"]
  end

  test "ignores fields not present" do
    assert_empty LegalFields.extract("texto sin datos")
  end

  test "reports invalid formats only for present values" do
    errors = LegalFields.invalid("rfc" => "XX1", "codigo_postal" => "", "nombre" => "cualquiera")

    assert_equal %w[rfc], errors.keys
  end
end
