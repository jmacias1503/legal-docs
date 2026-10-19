class CreateFirms < ActiveRecord::Migration[8.1]
  def change
    create_table :firms do |t|
      t.string :name
      t.string :rfc

      t.timestamps
    end
  end
end
