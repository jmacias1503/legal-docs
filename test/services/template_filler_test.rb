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
end
