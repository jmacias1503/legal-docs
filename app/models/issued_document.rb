# RF-03: documento autollenado emitido en PDF con folio, QR y hash SHA-256.
# El hash se calcula sobre el PDF final, así cualquier copia puede compararse en la página pública.
class IssuedDocument < ApplicationRecord
  belongs_to :document
  belongs_to :user, optional: true

  has_one_attached :file
  has_secure_token :token, length: 32, on: :initialize

  validates :sha256, :template_name, presence: true

  def self.issue!(document:, template:, text:, user:, verification_url:)
    issued = document.issued_documents.new(user:, template_name: template.name)
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

  def matches?(content) = ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(content), sha256)
end
