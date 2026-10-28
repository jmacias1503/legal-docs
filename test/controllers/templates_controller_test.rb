require "test_helper"

class TemplatesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { sign_in users(:one) }

  test "lists firm and library templates only" do
    get templates_path

    assert_response :success
    assert_match "Arrendamiento del despacho", response.body
    assert_match "Carta poder (biblioteca)", response.body
    assert_no_match "Plantilla ajena", response.body
  end

  test "library templates are visible but read-only" do
    get template_path(templates(:library))
    assert_response :success

    get edit_template_path(templates(:library))
    assert_response :not_found

    delete template_path(templates(:library))
    assert_response :not_found
  end

  test "cannot see another firm's templates" do
    get template_path(templates(:other_firm))

    assert_response :not_found
  end

  test "creates a template for the user's firm" do
    post templates_path, params: { template: { name: "Nueva", body: "Hola {{nombre}}" } }

    template = Template.order(:id).last
    assert_redirected_to template
    assert_equal firms(:one), template.firm
  end

  test "extracts body from uploaded file when body is blank" do
    assert_enqueued_with(job: TemplateTextJob) do
      post templates_path, params: { template: { name: "Desde archivo", file: fixture_file_upload("contrato.txt", "text/plain") } }
    end
  end

  test "saves field mappings without blank entries" do
    patch template_path(templates(:lease)), params: { template: { field_mappings: { "renta" => "monto", "nombre" => "" } } }

    assert_equal({ "renta" => "monto" }, templates(:lease).reload.field_mappings)
  end

  test "edit form shows mapping for each placeholder" do
    get edit_template_path(templates(:lease))

    assert_select "select[name='template[field_mappings][renta]']"
  end
end
