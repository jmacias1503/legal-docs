module ApplicationHelper
  STATUS_COLORS = {
    "draft" => "bg-gray-100 text-gray-800",
    "processing" => "bg-yellow-100 text-yellow-800",
    "completed" => "bg-blue-100 text-blue-800",
    "error" => "bg-red-100 text-red-800",
    "validated" => "bg-green-100 text-green-800"
  }.freeze

  def status_badge(document)
    tag.span(document.status_label, class: "inline-flex px-2.5 py-0.5 rounded-full text-xs font-medium #{STATUS_COLORS[document.status]}")
  end

  INPUT_CLASS = "mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm".freeze

  def input_class = INPUT_CLASS
end
