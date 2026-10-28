# DigitalLaw

Plataforma SaaS de digitalización y autollenado documental para despachos jurídicos, notarías y administradores de propiedades. Convierte expedientes físicos en datos estructurados con OCR y los usa para llenar formatos legales recurrentes, con trazabilidad completa.

Proyecto del equipo **Threno** (Universidad Autónoma de Querétaro): Alejandro Macias Fonseca, Blanca Isabel Pichardo Botillo y Daniel Zamorano Monzalvo.

- Requisitos: [`SRS_DigitalLaw.pdf`](SRS_DigitalLaw.pdf)
- Modelo de negocio: [`Modelo de Negocio Canvas - Digitalización para Despachos.pdf`](Modelo%20de%20Negocio%20Canvas%20-%20Digitalizaci%C3%B3n%20para%20Despachos.pdf), [`canvas digitalizacion despachos.pdf`](canvas%20digitalizacion%20despachos.pdf)
- Cronograma: [`Diagrama de Gantt_digitalizacion.pdf`](Diagrama%20de%20Gantt_digitalizacion.pdf) y su versión interactiva en [`public/gantt.html`](public/gantt.html) (`/gantt.html` con el servidor encendido)
- Estado detallado y backlog: [`PROJECT_AGENTS.md`](PROJECT_AGENTS.md), [`issues.md`](issues.md)

## Estado (28 de octubre de 2026)

| Requerimiento | Estado | Dónde |
| :--- | :--- | :--- |
| RF-01 Digitalización y OCR | ✅ | `OcrExtractor`, `LegalFields`, `DocumentOcrJob` |
| RF-02 Autollenado de formatos | ✅ | `TemplateFiller`, biblioteca legal en `db/seeds.rb` |
| RF-03 Verificación de documentos | ✅ PDF con QR y SHA-256. Pendiente: FIEL / DocuSign | `IssuedDocument`, `/verificar/:folio` |
| RF-04 Suscripciones SaaS | ✅ Planes y cobro por volumen. Pendiente: pasarela de pago | `Plan`, `MonthlyUsage`, página “Suscripción” |
| RF-05 Plantillas personalizadas | ✅ | `Template`, `TemplateTextJob` |
| RF-06 Bitácora de auditoría | ✅ Cambios, consultas, descargas, validación y emisión | PaperTrail, `Document#log_event!` |
| RF-07 Búsqueda y filtrado | ✅ Con ActiveRecord; `pg_search` al migrar a PostgreSQL | `Document.filter_by` |
| RNF-03 Procesamiento en segundo plano | ✅ Con Active Job | `app/jobs/` |
| RNF-06 API REST | ✅ | `app/controllers/api/v1/` |
| Despliegue en producción | ⏳ Faltan servidor, registro de imágenes y dominio | `config/deploy.yml` |

Según el Gantt, los módulos 1 y 2 están programados y la fase actual es **Testear módulo 1**: las pruebas automatizadas pasan y falta la prueba manual con expedientes escaneados reales. En noviembre siguen las pruebas del módulo 2 y el despliegue.

## Funcionalidad

**Documentos**
- Subida de PDF (con texto o escaneado), imágenes PNG/JPG/TIFF, Word `.docx` y texto. El OCR corre en segundo plano.
- Detección de nombre, contraparte, RFC, CURP, fechas, montos, expediente, escritura, notaría, domicilio y código postal. Corrige errores típicos del OCR en RFC y CURP y valida su formato.
- Edición manual de los datos. Lo capturado a mano nunca se sobrescribe al reprocesar.
- Validación de datos: un documento solo se marca como validado si todos sus datos tienen formato correcto.
- Búsqueda por título, cliente o contenido, con filtros por cliente, tipo de trámite, estado y fechas.

**Plantillas y autollenado**
- Plantillas propias del despacho (escritas a mano o extraídas de un PDF/Word) con marcadores `{{campo}}`, y mapeo de cada marcador a otro campo del documento.
- Biblioteca legal compartida, de solo lectura: contrato de arrendamiento, carta poder simple y escrito de promoción.
- Vista previa del autollenado con los campos faltantes marcados como `[CAMPO]`. Descarga en PDF, Word o `.txt`.
- **Emisión con sello:** genera un PDF definitivo con folio y QR y guarda su huella SHA-256. La página pública `/verificar/:folio` (sin sesión) muestra el despacho, el formato y la fecha, sin datos del cliente, y compara cualquier copia subida contra la huella. Solo se emite cuando no faltan datos y todos son válidos.

**Despachos, usuarios y suscripción**
- Cada usuario pertenece a un despacho y solo ve la información de su despacho. Quien se registra recibe un despacho propio y queda como administrador.
- Roles: administrador, abogado y asistente. Solo el administrador cambia el plan.
- Planes (precios en MXN):

  | Plan | Mensual | Anual | Documentos incluidos al mes |
  | :--- | ---: | ---: | ---: |
  | Prueba gratuita | $0 | $0 | 20 (límite duro) |
  | Básico | $499 | $4,990 | 100 |
  | Profesional | $1,499 | $14,990 | 500 |
  | Notaría | $3,999 | $39,990 | 2,000 |

  En los planes de pago, los documentos extra cuestan $5 cada uno los primeros 500 y $3 después. El uso se cuenta por mes y no baja al borrar documentos. La página “Suscripción” muestra el uso y el cargo estimado; todavía no hay cobro real.

**Bitácora (RF-06)**
Cada documento guarda quién lo creó, modificó, consultó, descargó, validó o emitió, y cuándo. La bitácora de usuarios no copia contraseñas ni tokens.

## API REST (`/api/v1`)

Cada usuario genera su token en la página **API** del menú. El token se muestra una sola vez y en la base solo se guarda su huella SHA-256. Se envía en el encabezado `Authorization: Bearer <token>`. La API solo da acceso a la información del despacho del usuario y cada operación queda en la bitácora.

| Método y ruta | Uso |
| :--- | :--- |
| `GET /api/v1/documents` | Lista con los mismos filtros de la web (`q`, `client`, `procedure_type`, `status`, `from`, `to`) y `page` (50 por página) |
| `GET /api/v1/documents/:id` | Detalle con texto OCR, datos detectados y errores de formato |
| `POST /api/v1/documents` | Crea un documento; con `document[file]` (multipart) lanza el OCR |
| `PATCH /api/v1/documents/:id` | Actualiza; `metadata` se combina con lo existente y un valor vacío borra el campo |
| `GET /api/v1/documents/:id/fill?template_id=` | Autollenado: texto, campos faltantes, inválidos y si está completo |
| `GET /api/v1/templates`, `GET /api/v1/templates/:id` | Plantillas disponibles, marcadores y mapeos |

```bash
curl -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/v1/documents?status=validated"
```

## Stack

- Ruby 3.4.10 y Rails 8.1 con Hotwire (Turbo y Stimulus) y Tailwind
- Devise (autenticación), Active Storage (archivos), PaperTrail (bitácora)
- Active Job para OCR y extracción de plantillas
- Prawn y rqrcode (PDF con QR), rubyzip (Word `.docx`)
- SQLite en desarrollo y pruebas. El SRS contempla PostgreSQL, almacenamiento tipo S3 y Sidekiq/Redis en producción; las gemas están en el Gemfile pero aún no se configuran.
- Docker, Kamal y Thruster para el despliegue

## Instalación

### Dependencias del sistema

El OCR usa herramientas externas: `poppler` (`pdftotext`, `pdftoppm`), `tesseract` con el idioma español, y `unzip`. En Arch Linux:

```bash
sudo pacman -S poppler tesseract tesseract-data-spa unzip
```

Sin `tesseract-data-spa` se usa el primer idioma disponible y baja la precisión. El idioma se puede forzar con la variable `OCR_LANG`.

### Aplicación

```bash
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/dev
```

`db:seed` carga la biblioteca legal. La aplicación queda en `http://localhost:3000`; regístrate para crear tu despacho.

### Pruebas

```bash
bin/rails test
```

76 pruebas: modelos, servicios (OCR, detección de datos, autollenado), jobs, controladores web, API e integración de registro. La prueba de extracción de PDF se omite si `pdftotext` no está instalado.

Análisis estático y de seguridad:

```bash
bin/rubocop
```

```bash
bin/brakeman
```

## Estructura

```
app/
  models/        Document, Template, Firm, User, IssuedDocument, Plan, MonthlyUsage
  services/      OcrExtractor, LegalFields, TemplateFiller, DocumentExport
  jobs/          DocumentOcrJob, TemplateTextJob
  controllers/   documents, templates, subscriptions, api_tokens, verifications, api/v1/*
db/seeds.rb      Biblioteca legal
public/gantt.html  Cronograma interactivo
slides/          Presentación de avances (Slidev)
```

## Notas

- La gema `json` está fijada en `~> 2.16`: la versión 3.x rompe la lectura de columnas JSON en Rails 8.1.
- Los QR apuntan a la dirección desde la que se emitió el documento. En producción hay que emitir desde el dominio público definitivo.
- Pendientes principales: despliegue (servidor, dominio, PostgreSQL, S3 y cola de trabajos), pasarela de pago y facturación CFDI, firma electrónica avanzada (FIEL / DocuSign), y respaldos automáticos (RNF-05).
