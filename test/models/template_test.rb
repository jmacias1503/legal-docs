require "test_helper"

class TemplateTest < ActiveSupport::TestCase
  test "lists unique placeholders" do
    template = Template.new(body: "{{ Nombre }} y {{rfc}} y {{nombre}}")

    assert_equal %w[nombre rfc], template.placeholders
  end

  test "maps placeholders to source fields" do
    assert_equal "monto", templates(:lease).source_for("renta")
    assert_equal "nombre", templates(:lease).source_for("nombre")
  end

  test "templates without firm belong to the legal library" do
    assert templates(:library).library?
    assert_not templates(:lease).library?
  end
end
