class Template < ApplicationRecord
  has_paper_trail

  # Sin despacho = plantilla de la biblioteca legal compartida (solo lectura).
  belongs_to :firm, optional: true

  has_one_attached :file

  PLACEHOLDER = /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/

  validates :name, presence: true

  scope :library, -> { where(firm_id: nil) }
  # Las del despacho más la biblioteca legal.
  scope :available_to, ->(firm) { where(firm: [ firm, nil ]) }

  def library? = firm_id.nil?

  def placeholders = body.to_s.scan(PLACEHOLDER).flatten.map(&:downcase).uniq

  # RF-05: cada marcador puede tomar su valor de otro campo del documento.
  def source_for(placeholder) = field_mappings.to_h[placeholder].presence || placeholder
end
