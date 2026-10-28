class AddOcrAndAutofillFields < ActiveRecord::Migration[8.1]
  def change
    change_table :documents do |t|
      t.string :client
      t.string :procedure_type
      t.text :extracted_text
      t.string :ocr_error
      t.index :status
      t.index :procedure_type
    end

    change_table :templates do |t|
      t.text :body
      t.json :field_mappings
    end
  end
end
