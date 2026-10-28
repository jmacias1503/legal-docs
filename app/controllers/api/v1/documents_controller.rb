module Api
  module V1
    class DocumentsController < BaseController
      PER_PAGE = 50

      before_action :set_document, only: %i[show update fill]

      # Acepta los mismos filtros que la vista web (RF-07): q, client, procedure_type, status, from, to.
      def index
        page = [ params[:page].to_i, 1 ].max
        documents = current_firm.documents.filter_by(params).order(created_at: :desc).limit(PER_PAGE).offset((page - 1) * PER_PAGE)
        render json: { page:, per_page: PER_PAGE, documents: documents.map { |document| document_json(document) } }
      end

      def show
        @document.log_event!("access")
        render json: document_json(@document, full: true)
      end

      def create
        document = current_firm.documents.new(document_params.merge(user: current_user))
        if document.save
          document.process_file_later
          render json: document_json(document, full: true), status: :created
        else
          render json: { errors: document.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # Los datos enviados en metadata se combinan con los existentes; un valor vacío elimina el campo.
      def update
        attributes = document_params
        attributes[:metadata] = @document.metadata.merge(attributes[:metadata].to_h) if attributes.key?(:metadata)

        if @document.update(attributes)
          @document.process_file_later if attributes[:file].present?
          render json: document_json(@document, full: true)
        else
          render json: { errors: @document.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # RF-02: autollenado de una plantilla con los datos del documento.
      def fill
        template = Template.available_to(current_firm).find(params.require(:template_id))
        result = TemplateFiller.call(template, @document)
        render json: { text: result.text, missing: result.missing, invalid: result.invalid, complete: result.complete? }
      end

      private

      def set_document
        @document = current_firm.documents.find(params[:id])
      end

      def document_params
        params.expect(document: [ :title, :client, :procedure_type, :file, metadata: {} ])
      end

      def document_json(document, full: false)
        fields = %i[id title client procedure_type status metadata ocr_error created_at updated_at]
        fields << :extracted_text if full
        document.as_json(only: fields).merge("data_errors" => document.data_errors)
      end
    end
  end
end
