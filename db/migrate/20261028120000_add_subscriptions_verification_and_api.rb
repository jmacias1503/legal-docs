# RF-03 (documentos emitidos con hash SHA-256), RF-04 (planes y uso mensual) y RNF-06 (token de API).
class AddSubscriptionsVerificationAndApi < ActiveRecord::Migration[8.1]
  def change
    add_column :firms, :plan, :string, null: false, default: "prueba"
    add_column :firms, :billing_cycle, :string, null: false, default: "monthly"

    create_table :monthly_usages do |t|
      t.references :firm, null: false, foreign_key: true
      t.date :month, null: false
      t.integer :documents_count, null: false, default: 0
      t.timestamps
    end
    add_index :monthly_usages, %i[firm_id month], unique: true

    create_table :issued_documents do |t|
      t.references :document, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :token, null: false
      t.string :sha256, null: false
      t.string :template_name, null: false
      t.timestamps
    end
    add_index :issued_documents, :token, unique: true
    add_index :issued_documents, :sha256

    add_column :users, :api_token_digest, :string
    add_index :users, :api_token_digest, unique: true
  end
end
