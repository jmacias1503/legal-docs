# RF-03: documento autollenado emitido en PDF con folio, QR y hash SHA-256.
# El hash se calcula sobre el PDF final, así cualquier copia puede compararse en la página pública.
class IssuedDocument < ApplicationRecord
  GENERIC_FORMAT_NAME = "Formato personalizado del despacho".freeze

  belongs_to :document
  belongs_to :user, optional: true

  has_one_attached :file
  has_secure_token :token, length: 32, on: :initialize

  validates :sha256, :template_name, presence: true

  def self.issue!(document:, template:, text:, user:, verification_url:)
    issued = document.issued_documents.new(user:, template_name: template.name, library_template: template.library?)
    url = verification_url.call(issued.token)
    pdf = DocumentExport.pdf(text, title: document.title, verification: { url:, folio: issued.token })

    issued.sha256 = Digest::SHA256.hexdigest(pdf)
    issued.file.attach(io: StringIO.new(pdf), filename: "#{document.title}-#{template.name}".parameterize + ".pdf",
                       content_type: "application/pdf")
    transaction do
      issued.save!
      document.log_event!("issue")
    end
    issued
  end

  # Nombre apto para la página pública: los formatos del despacho son texto libre y pueden
  # contener datos del cliente, así que solo se revela el nombre de los de la biblioteca legal.
  def public_format_name = library_template? ? template_name : GENERIC_FORMAT_NAME

  def matches?(content) = ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(content), sha256)
end
