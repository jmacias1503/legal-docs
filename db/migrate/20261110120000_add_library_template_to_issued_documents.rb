# LFPDPPP (RNF-01): la página pública solo puede mostrar el nombre del formato si viene de la biblioteca
# legal; los nombres de formatos del despacho son texto libre y podrían contener datos del cliente.
# Los folios ya emitidos quedan en false (nombre genérico) porque no se puede saber su origen con certeza.
class AddLibraryTemplateToIssuedDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :issued_documents, :library_template, :boolean, default: false, null: false
  end
end
