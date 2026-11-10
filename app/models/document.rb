class Document < ApplicationRecord
  has_paper_trail

  belongs_to :firm
  belongs_to :user, optional: true

  has_one_attached :file
  has_many :issued_documents, dependent: :destroy

  attribute :metadata, default: -> { {} }

  enum :status, {
    draft: 0,
    processing: 1,
    completed: 2,
    error: 3,
    validated: 4
  }, default: :draft

  STATUS_LABELS = {
    "draft" => "Borrador",
    "processing" => "Procesando OCR",
    "completed" => "Datos extraídos",
    "error" => "Error de OCR",
    "validated" => "Validado"
  }.freeze

  ACCEPTED_FILE_TYPES = %w[application/pdf image/png image/jpeg image/tiff text/plain] + [ OcrExtractor::DOCX ]

  validates :title, presence: true
  validate :file_type_supported
  validate :within_plan_quota, on: :create

  after_create { MonthlyUsage.record!(firm) }

  # Las claves se normalizan (ej. "Precio Renta" -> "precio_renta") y los campos vacíos se eliminan.
  def metadata=(value)
    super(value.to_h.transform_keys { |key| key.to_s.parameterize(separator: "_") }.compact_blank)
  end

  # RF-07: búsqueda por texto y filtros por metadatos.
  def self.filter_by(params)
    scope = all
    q = text_param(params[:q])
    client = text_param(params[:client])
    procedure_type = text_param(params[:procedure_type])
    status = text_param(params[:status])
    from = text_param(params[:from])
    to = text_param(params[:to])

    if q
      # Arel `matches` genera ILIKE en PostgreSQL y LIKE en SQLite (ambos sin distinguir mayúsculas).
      scope = scope.where(
        contains(:title, q)
          .or(contains(:client, q))
          .or(contains(:extracted_text, q))
      )
    end
    scope = scope.where(contains(:client, client)) if client
    scope = scope.where(procedure_type: procedure_type) if procedure_type
    scope = scope.where(status: status) if status && statuses.key?(status)
    scope = scope.where(created_at: Date.parse(from).beginning_of_day..) if valid_date?(from)
    scope = scope.where(created_at: ..Date.parse(to).end_of_day) if valid_date?(to)
    scope
  end

  # Solo se aceptan cadenas no vacías; arreglos/hashes (`q[]=x`) se ignoran como si no vinieran.
  def self.text_param(value)
    value.is_a?(String) && value.present? ? value : nil
  end
  private_class_method :text_param

  def self.valid_date?(value)
    value.present? && Date.parse(value)
  rescue Date::Error
    false
  end
  private_class_method :valid_date?

  # LIKE "contiene" con escape explícito: SQLite no tiene escape por defecto (PostgreSQL usa "\").
  def self.contains(column, value)
    arel_table[column].matches("%#{sanitize_sql_like(value.strip)}%", "\\", false)
  end
  private_class_method :contains

  def status_label = STATUS_LABELS.fetch(status, status.to_s.humanize)

  # Valores disponibles para autollenar plantillas.
  def field_values
    {
      "titulo" => title,
      "cliente" => client,
      "tipo_tramite" => procedure_type,
      "fecha_actual" => I18n.l(Date.current, format: "%d/%m/%Y")
    }.merge(metadata.to_h.transform_keys(&:to_s)).compact_blank
  end

  def data_errors = LegalFields.invalid(metadata)

  AUDIT_EVENTS = {
    "create" => "Creado", "update" => "Modificado", "destroy" => "Eliminado",
    "access" => "Consultado", "download" => "Descargado", "validate" => "Validado", "issue" => "Emitido con sello"
  }.freeze

  # RF-06: los accesos y descargas también quedan en la bitácora, con el usuario de la petición.
  def log_event!(event)
    versions.create!(event:, whodunnit: PaperTrail.request.whodunnit)
  end

  def process_file_later
    return unless file.attached?

    update!(status: :processing, ocr_error: nil)
    DocumentOcrJob.perform_later(self)
  end

  private

  def within_plan_quota
    return if firm.nil? || firm.can_add_document?

    errors.add(:base, "El plan #{firm.subscription_plan.name} llegó a su límite de #{firm.subscription_plan.included_documents} documentos este mes. Cambia de plan para continuar.")
  end

  def file_type_supported
    return unless file.attached? && !ACCEPTED_FILE_TYPES.include?(file.content_type)

    errors.add(:file, "debe ser PDF, imagen (PNG/JPG/TIFF), Word (.docx) o texto")
  end
end
