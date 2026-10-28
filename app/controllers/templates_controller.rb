class TemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_editable_template, only: %i[edit update destroy]

  def index
    @templates = Template.available_to(current_firm).order(Arel.sql("firm_id IS NULL"), :name)
  end

  def show
    @template = Template.available_to(current_firm).find(params[:id])
  end

  def new
    @template = current_firm.templates.new
  end

  def edit
  end

  def create
    @template = current_firm.templates.new(template_params)

    if @template.save
      TemplateTextJob.perform_later(@template) if @template.body.blank? && @template.file.attached?
      redirect_to @template, notice: "Plantilla creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @template.update(template_params)
      TemplateTextJob.perform_later(@template) if @template.body.blank? && @template.file.attached?
      redirect_to @template, notice: "Plantilla actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @template.destroy
    redirect_to templates_path, notice: "Plantilla eliminada."
  end

  private

  # Las plantillas de la biblioteca legal son de solo lectura.
  def set_editable_template
    @template = current_firm.templates.find(params[:id])
  end

  def template_params
    permitted = params.expect(template: [ :name, :body, :file, field_mappings: {} ])
    if permitted.key?(:field_mappings)
      permitted[:field_mappings] = permitted[:field_mappings].to_h
                                                             .transform_values { |value| value.to_s.parameterize(separator: "_") }
                                                             .compact_blank
    end
    permitted
  end
end
