# RF-04: contador de documentos por despacho y mes. No baja al borrar documentos,
# así el cobro por volumen refleja lo realmente procesado.
class MonthlyUsage < ApplicationRecord
  belongs_to :firm

  def self.record!(firm, month = Date.current.beginning_of_month)
    usage = create_or_find_by!(firm:, month:)
    update_counters(usage.id, documents_count: 1)
  end
end
