require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "filters by text, client, procedure type, status and date" do
    firm_docs = firms(:one).documents

    assert_equal [ documents(:lease) ], firm_docs.filter_by(q: "Universidad").to_a
    assert_equal [ documents(:power) ], firm_docs.filter_by(client: "gómez").to_a
    assert_equal [ documents(:power) ], firm_docs.filter_by(procedure_type: "Poder notarial").to_a
    assert_equal [ documents(:lease) ], firm_docs.filter_by(status: "completed").to_a
    assert_empty firm_docs.filter_by(from: 1.day.from_now.to_date.to_s)
    assert_equal 2, firm_docs.filter_by(status: "inexistente", from: "no-es-fecha").count
  end

  test "escapes LIKE wildcards in search" do
    assert_empty firms(:one).documents.filter_by(q: "%")
  end

  test "exposes document attributes and metadata for autofill" do
    values = documents(:lease).field_values

    assert_equal "Juan Pérez", values["cliente"]
    assert_equal "PELJ800101AB1", values["rfc"]
    assert values["fecha_actual"].present?
  end

  test "process_file_later marks processing and enqueues OCR" do
    document = documents(:power)
    document.file.attach(io: file_fixture("contrato.txt").open, filename: "contrato.txt", content_type: "text/plain")

    assert_enqueued_with(job: DocumentOcrJob, args: [ document ]) { document.process_file_later }
    assert document.reload.processing?
  end

  test "rejects unsupported file types" do
    document = documents(:power)
    document.file.attach(io: StringIO.new("zip"), filename: "a.zip", content_type: "application/zip")

    assert_not document.valid?
    assert document.errors[:file].any?
  end

  test "counts monthly usage and blocks new documents when the trial limit is reached" do
    firm = firms(:one)
    assert_difference -> { firm.documents_this_month }, 1 do
      firm.documents.create!(title: "Nuevo", user: users(:one))
    end

    MonthlyUsage.find_by(firm:, month: Date.current.beginning_of_month).update!(documents_count: 20)
    document = firm.documents.new(title: "Excedente", user: users(:one))
    assert_not document.valid?
    assert_match "límite", document.errors[:base].first

    firm.update!(plan: "basico")
    assert document.valid?
  end

  test "deleting documents does not reduce usage" do
    firm = firms(:one)
    firm.documents.create!(title: "Temporal", user: users(:one)).destroy

    assert_equal 1, firm.documents_this_month
  end

  test "normalizes metadata keys and drops blank values" do
    document = Document.new(metadata: { "Precio Renta" => "$1", "rfc" => "" })

    assert_equal({ "precio_renta" => "$1" }, document.metadata)
  end

  test "logs access events with the current user" do
    PaperTrail.request(whodunnit: users(:one).id.to_s) { documents(:lease).log_event!("access") }

    version = documents(:lease).versions.last
    assert_equal "access", version.event
    assert_equal users(:one).id.to_s, version.whodunnit
  end
end
