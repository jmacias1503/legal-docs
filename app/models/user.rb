class User < ApplicationRecord
  # Las credenciales no se copian a la bitácora.
  has_paper_trail skip: %i[encrypted_password reset_password_token api_token_digest]

  belongs_to :firm
  has_many :documents, dependent: :nullify

  enum :role, {
    admin: 0,
    lawyer: 1,
    assistant: 2
  }, default: :lawyer

  validates :email, presence: true, uniqueness: true
  validates :first_name, :last_name, presence: true

  before_validation :assign_personal_firm, on: :create

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  def full_name
    "#{first_name} #{last_name}"
  end

  # RNF-06: el token solo se muestra al generarlo; se guarda su SHA-256.
  def self.find_by_api_token(token)
    find_by(api_token_digest: api_digest(token)) if token.present?
  end

  def self.api_digest(token) = Digest::SHA256.hexdigest(token)

  def regenerate_api_token!
    SecureRandom.base58(32).tap { |token| update!(api_token_digest: self.class.api_digest(token)) }
  end

  def revoke_api_token! = update!(api_token_digest: nil)

  private

  # Quien se registra sin despacho obtiene uno propio para aislar su información y lo administra.
  def assign_personal_firm
    return if firm

    self.firm = Firm.new(name: "Despacho de #{full_name.strip.presence || email}")
    self.role = :admin
  end
end
