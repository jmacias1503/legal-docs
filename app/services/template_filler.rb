# Llena una plantilla con los datos de un documento (RF-02).
# Los campos faltantes quedan marcados como [CAMPO] para revisión manual.
class TemplateFiller
  Result = Data.define(:text, :missing, :invalid) do
    def complete? = missing.empty? && invalid.empty?
  end

  def self.call(template, document)
    values = document.field_values
    used = {}
    missing = []

    text = template.body.to_s.gsub(Template::PLACEHOLDER) do
      placeholder = $1.downcase
      source = template.source_for(placeholder)
      value = values[source]
      if value.present?
        used[source] = value
        value
      else
        missing << placeholder
        "[#{placeholder.upcase}]"
      end
    end

    Result.new(text:, missing: missing.uniq, invalid: LegalFields.invalid(used).values)
  end
end
