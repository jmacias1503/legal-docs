module Api
  module V1
    class TemplatesController < BaseController
      def index
        render json: Template.available_to(current_firm).order(:name).map { |template| template_json(template) }
      end

      def show
        template = Template.available_to(current_firm).find(params[:id])
        render json: template_json(template).merge("body" => template.body)
      end

      private

      def template_json(template)
        { "id" => template.id, "name" => template.name, "library" => template.library?,
          "placeholders" => template.placeholders, "field_mappings" => template.field_mappings.to_h }
      end
    end
  end
end
