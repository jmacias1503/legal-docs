# Biblioteca legal compartida (RF-02): plantillas sin despacho, visibles para todos en solo lectura.
LIBRARY = {
  "Contrato de arrendamiento" => <<~TXT,
    CONTRATO DE ARRENDAMIENTO

    En la ciudad de Querétaro, a {{fecha_actual}}, comparecen por una parte el C. {{nombre}},
    con RFC {{rfc}}, en lo sucesivo "EL ARRENDADOR", y por la otra el C. {{contraparte}},
    en lo sucesivo "EL ARRENDATARIO", quienes convienen en sujetarse a las siguientes:

    CLÁUSULAS

    PRIMERA. EL ARRENDADOR otorga en arrendamiento el inmueble con domicilio en {{domicilio}},
    C.P. {{codigo_postal}}.

    SEGUNDA. La renta mensual será de {{monto}}, pagadera dentro de los primeros cinco días de cada mes.

    TERCERA. El presente contrato inicia su vigencia el {{fecha}}.


    ______________________                ______________________
    EL ARRENDADOR                         EL ARRENDATARIO
  TXT
  "Carta poder simple" => <<~TXT,
    CARTA PODER

    Querétaro, a {{fecha_actual}}

    Por medio de la presente, yo, {{nombre}}, con CURP {{curp}}, otorgo poder amplio y suficiente
    al C. {{contraparte}} para que en mi nombre y representación realice los trámites relativos a
    {{tipo_tramite}} ante las autoridades correspondientes.


    ______________________     ______________________     ______________________
    OTORGANTE                  APODERADO                  TESTIGO
  TXT
  "Escrito de promoción en expediente" => <<~TXT
    {{cliente}}
    EXPEDIENTE: {{expediente}}

    C. JUEZ COMPETENTE
    P R E S E N T E

    {{nombre}}, con RFC {{rfc}}, señalando como domicilio para oír y recibir notificaciones el
    ubicado en {{domicilio}}, ante usted con el debido respeto comparezco para exponer:

    Que por medio del presente escrito vengo a promover dentro del expediente al rubro citado.

    PROTESTO LO NECESARIO
    Querétaro, a {{fecha_actual}}
  TXT
}.freeze

LIBRARY.each do |name, body|
  Template.library.find_or_create_by!(name:) { |template| template.body = body }
end
