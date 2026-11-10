require "test_helper"

class IssuedDocumentTest < ActiveSupport::TestCase
  test "public_format_name shows the real name only for library templates" do
    assert_equal "Contrato de arrendamiento",
                 IssuedDocument.new(template_name: "Contrato de arrendamiento", library_template: true).public_format_name
  end

  test "public_format_name is generic for firm templates" do
    issued = IssuedDocument.new(template_name: "Contrato Juan Pérez", library_template: false)
    assert_equal "Formato personalizado del despacho", issued.public_format_name
  end

  test "issue! copies template.library? into library_template" do
    { templates(:library) => true, templates(:lease) => false }.each do |template, expected|
      issued = IssuedDocument.issue!(
        document: documents(:lease), template:, text: "Texto de prueba", user: users(:one),
        verification_url: ->(token) { "http://example.test/verificar/#{token}" }
      )
      assert_equal expected, issued.reload.library_template?, template.name
    end
  end

  test "library_template defaults to false so legacy records stay generic" do
    assert_not IssuedDocument.new(template_name: "Cualquiera").library_template?
    assert_equal "Formato personalizado del despacho", IssuedDocument.new(template_name: "Cualquiera").public_format_name
  end
end
