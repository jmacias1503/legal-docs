class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_document, except: %i[index new create]

  def index
    @documents = current_firm.documents.filter_by(params).order(created_at: :desc)
    @procedure_types = current_firm.documents.where.not(procedure_type: [ nil, "" ]).distinct.order(:procedure_type).pluck(:procedure_type)
  end

  def show
    @document.log_event!("access")
    @issued_documents = @document.issued_documents.order(created_at: :desc)
    @templates = available_templates.order(:name)
    @versions = @document.versions.reorder(created_at: :desc).limit(20)
    @authors = User.where(id: @versions.filter_map(&:whodunnit)).index_by { |user| user.id.to_s }
  end

  def new
    @document = current_firm.documents.new
  end

  def edit
  end

  def create
    @document = current_firm.documents.new(document_attributes.merge(user: current_user))

    if @document.save
      @document.process_file_later
      redirect_to @document, notice: notice_for("Documento creado.")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @document.update(document_attributes)
      @document.process_file_later if params.dig(:document, :file).present?
      redirect_to @document, notice: notice_for("Documento actualizado.")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @document.destroy
    redirect_to documents_path, notice: "Documento eliminado."
  end

  # RF-01: volver a ejecutar OCR sobre el archivo actual.
  def reprocess
    if @document.file.attached?
      @document.process_file_later
      redirect_to @document, notice: "OCR en proceso."
    else
      redirect_to @document, alert: "El documento no tiene archivo."
    end
  end

  # RF-02: el usuario confirma que los datos extraídos son correctos.
  def confirm
    errors = @document.data_errors
    if errors.any?
      redirect_to @document, alert: "Corrige los datos antes de validar: #{errors.values.to_sentence}"
    else
      @document.paper_trail_event = "validate"
      @document.validated!
      redirect_to @document, notice: "Datos validados."
    end
  end

  # RF-02: vista previa / descarga del documento autollenado (texto, PDF o Word).
  def fill
    @template = available_templates.find(params[:template_id])
    @result = TemplateFiller.call(@template, @document)

    respond_to do |format|
      format.html
      format.text { send_filled(@result.text, "txt", "text/plain; charset=utf-8") }
      format.pdf { send_filled(DocumentExport.pdf(@result.text, title: @document.title), "pdf", "application/pdf") }
      format.docx { send_filled(DocumentExport.docx(@result.text), "docx", DocumentExport::DOCX) }
    end
  end

  # RF-03: emite el PDF definitivo con folio, QR de verificación y hash SHA-256.
  def issue
    template = available_templates.find(params[:template_id])
    result = TemplateFiller.call(template, @document)
    unless result.complete?
      return redirect_to fill_document_path(@document, template_id: template.id),
                         alert: "Completa y corrige los datos antes de emitir el documento."
    end

    issued = IssuedDocument.issue!(document: @document, template:, text: result.text, user: current_user,
                                   verification_url: ->(token) { verification_url(token) })
    redirect_to @document, notice: "Documento emitido. Folio: #{issued.token}"
  end

  private

  def set_document
    @document = current_firm.documents.find(params[:id])
  end

  def available_templates = Template.available_to(current_firm)

  def notice_for(message)
    @document.processing? ? "#{message} El OCR se está procesando en segundo plano." : message
  end

  def document_params
    params.expect(document: [ :title, :client, :procedure_type, :file, :new_field_key, :new_field_value, metadata: {} ])
  end

  def document_attributes
    attributes = document_params.except(:metadata, :new_field_key, :new_field_value)
    return attributes unless params.dig(:document, :metadata) || document_params[:new_field_key].present?

    metadata = document_params.fetch(:metadata, {}).to_h
    metadata[document_params[:new_field_key]] = document_params[:new_field_value] if document_params[:new_field_key].present?
    attributes.merge(metadata:)
  end

  def send_filled(data, extension, type)
    @document.log_event!("download")
    send_data data, filename: "#{@document.title}-#{@template.name}".parameterize + ".#{extension}", type:
  end
end
