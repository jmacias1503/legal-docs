# Las plantillas sin despacho forman la biblioteca legal compartida (RF-02).
class AllowLibraryTemplates < ActiveRecord::Migration[8.1]
  def change
    change_column_null :templates, :firm_id, true
  end
end
