class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.string :title
      t.references :firm, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :status
      t.json :metadata

      t.timestamps
    end
  end
end
