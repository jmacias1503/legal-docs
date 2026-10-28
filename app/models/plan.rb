# RF-04: planes de suscripción SaaS. Precios en centavos (MXN).
# El volumen se mide por documentos subidos en el mes calendario.
class Plan < Data.define(:key, :name, :monthly_cents, :annual_cents, :included_documents, :overage)
  # Escalafones para documentos excedentes: [hasta N excedentes, precio por documento].
  OVERAGE_TIERS = [ [ 500, 5_00 ], [ Float::INFINITY, 3_00 ] ].freeze

  PLANS = [
    new("prueba", "Prueba gratuita", 0, 0, 20, false),
    new("basico", "Básico", 499_00, 4_990_00, 100, true),
    new("profesional", "Profesional", 1_499_00, 14_990_00, 500, true),
    new("notaria", "Notaría", 3_999_00, 39_990_00, 2_000, true)
  ].index_by(&:key).freeze

  def self.all = PLANS.values
  def self.find(key) = PLANS.fetch(key.to_s)
  def self.keys = PLANS.keys

  def free? = monthly_cents.zero?

  # Sin cobro por excedente el plan tiene un límite duro.
  def allows?(documents_used) = overage || documents_used < included_documents

  def base_cents(billing_cycle) = billing_cycle == "annual" ? annual_cents : monthly_cents

  def overage_cents(documents_used)
    return 0 unless overage

    extra = [ documents_used - included_documents, 0 ].max
    floor = 0
    OVERAGE_TIERS.sum do |limit, price|
      in_tier = ([ extra, limit ].min - floor).clamp(0..)
      floor = limit
      in_tier * price
    end
  end
end
