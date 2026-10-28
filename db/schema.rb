# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_28_120000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "documents", force: :cascade do |t|
    t.string "client"
    t.datetime "created_at", null: false
    t.text "extracted_text"
    t.integer "firm_id", null: false
    t.json "metadata"
    t.string "ocr_error"
    t.string "procedure_type"
    t.integer "status"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["firm_id"], name: "index_documents_on_firm_id"
    t.index ["procedure_type"], name: "index_documents_on_procedure_type"
    t.index ["status"], name: "index_documents_on_status"
    t.index ["user_id"], name: "index_documents_on_user_id"
  end

  create_table "firms", force: :cascade do |t|
    t.string "billing_cycle", default: "monthly", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.string "plan", default: "prueba", null: false
    t.string "rfc"
    t.datetime "updated_at", null: false
  end

  create_table "issued_documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "document_id", null: false
    t.string "sha256", null: false
    t.string "template_name", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["document_id"], name: "index_issued_documents_on_document_id"
    t.index ["sha256"], name: "index_issued_documents_on_sha256"
    t.index ["token"], name: "index_issued_documents_on_token", unique: true
    t.index ["user_id"], name: "index_issued_documents_on_user_id"
  end

  create_table "monthly_usages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "documents_count", default: 0, null: false
    t.integer "firm_id", null: false
    t.date "month", null: false
    t.datetime "updated_at", null: false
    t.index ["firm_id", "month"], name: "index_monthly_usages_on_firm_id_and_month", unique: true
    t.index ["firm_id"], name: "index_monthly_usages_on_firm_id"
  end

  create_table "templates", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.json "field_mappings"
    t.integer "firm_id"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["firm_id"], name: "index_templates_on_firm_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "api_token_digest"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "firm_id"
    t.string "first_name"
    t.string "last_name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role"
    t.datetime "updated_at", null: false
    t.index ["api_token_digest"], name: "index_users_on_api_token_digest", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["firm_id"], name: "index_users_on_firm_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object", limit: 1073741823
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "documents", "firms"
  add_foreign_key "documents", "users"
  add_foreign_key "issued_documents", "documents"
  add_foreign_key "issued_documents", "users"
  add_foreign_key "monthly_usages", "firms"
  add_foreign_key "templates", "firms"
end
