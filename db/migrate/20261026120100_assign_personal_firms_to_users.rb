# Cada usuario debe pertenecer a un despacho para aislar sus documentos y plantillas.
class AssignPersonalFirmsToUsers < ActiveRecord::Migration[8.1]
  class MigrationFirm < ActiveRecord::Base
    self.table_name = "firms"
  end

  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    MigrationUser.where(firm_id: nil).find_each do |user|
      name = [ user.first_name, user.last_name ].compact_blank.join(" ").presence || user.email
      firm = MigrationFirm.create!(name: "Despacho de #{name}")
      user.update_columns(firm_id: firm.id)
    end
  end

  def down
    # Irreversible sin pérdida: los despachos personales se conservan.
  end
end
