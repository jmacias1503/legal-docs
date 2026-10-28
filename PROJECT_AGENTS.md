# PROJECT_AGENTS.md - Estado y Seguimiento del Proyecto (DigitalLaw)

Este documento sirve como registro oficial y guía para agentes de IA que accedan al proyecto, manteniendo el estado actual, la arquitectura implementada, alineación con el SRS y Modelos Canvas, instrucciones para la ejecución y el cronograma basado en el Diagrama de Gantt.

---

## 1. Información General del Proyecto
- **Nombre**: DigitalLaw / Digitalización y Autollenado Documental (`legal-docs-aps`)
- **Equipo**: Threno (Universidad Autónoma de Querétaro - UAQ)
- **Periodo del Cronograma**: 1 de septiembre al 15 de diciembre (2026)
- **Fecha actual de referencia**: 28 de octubre de 2026
- **Stack Tecnológico**: 
  - **Framework**: Ruby on Rails 8.1 (con Hotwire)
  - **Autenticación**: Devise (usuarios, roles, relación con Firmas/Despachos)
  - **Base de Datos**: PostgreSQL (en producción) / SQLite (desarrollo/test) con Active Record
  - **Gestión de Archivos**: Active Storage (almacenamiento en la nube tipo S3)
  - **Control de Versiones y Auditoría**: PaperTrail (tabla `versions` para Audit Log)
  - **Búsqueda Avanzada**: `pg_search` (para filtrado de expedientes y metadatos)
  - **Background Jobs / Cola**: Sidekiq / Solid Queue, Redis (para procesamiento pesado de OCR y PDF)
  - **Contenedores y Despliegue**: Docker, Kamal, Thruster, Puma

---

## 2. Alineación con el SRS (DigitalLaw) y Modelo Canvas

El proyecto se alinea estrictamente con la Especificación de Requisitos de Software (SRS) y el Business Model Canvas de **DigitalLaw**:

- **Segmentos de Clientes**: Despachos Jurídicos, Notarías Públicas y Administradores de Propiedades.
- **Propuesta de Valor**: 
  - Transformación de documentos físicos a datos estructurados mediante OCR jurídico.
  - Autollenado de formatos legales recurrentes.
  - Trazabilidad, seguridad y cumplimiento normativo (LFPDPPP).
- **Requerimientos Funcionales del SRS**:
  - **RF-01 (Digitalización y OCR)**: Extracción de texto con IA especializada en jerga jurídica. *(✅ Implementado: `OcrExtractor` (pdftotext/Tesseract/Word) + `DocumentOcrJob` + detección de datos en `LegalFields`)*
  - **RF-02 (Autollenado de Formatos)**: Biblioteca legal y llenado automático de plantillas. *(✅ Implementado: `TemplateFiller`, biblioteca legal en `db/seeds.rb`, validación de datos)*
  - **RF-03 (Verificación de Entidades)**: Generación de Hash SHA-256 / códigos QR o integración con Firma Electrónica (FIEL/DocuSign). *(✅ Implementado: `IssuedDocument` emite el PDF con folio + QR, guarda su SHA-256 y la página pública `/verificar/:folio` compara cualquier copia. Integración FIEL/DocuSign pendiente)*
  - **RF-04 (Sistema de Suscripciones SaaS)**: Gestión de planes mensuales/anuales y escalafones por volumen. *(✅ Implementado: `Plan` (Prueba/Básico/Profesional/Notaría), uso mensual en `MonthlyUsage`, límite duro en prueba, excedente por escalafones, página “Suscripción”. Falta pasarela de pago)*
  - **RF-05 (Gestión de Plantillas Personalizadas)**: Subida y edición de formatos (PDF/Word) con mapeo de campos. *(✅ Implementado: subida PDF/Word/texto, cuerpo con marcadores `{{campo}}` y mapeo de campos)*
  - **RF-06 (Historial de Auditoría / Audit Log)**: Registro inmutable con PaperTrail. *(✅ Implementado: PaperTrail con usuario responsable; además registra consultas, descargas, validación y emisión (`Document#log_event!`))*
  - **RF-07 (Búsqueda y Filtrado Avanzado)**: Búsqueda por texto (título, cliente, contenido OCR) y filtros por cliente, tipo de trámite, estado y fechas (`Document.filter_by`). *(✅ Implementado con ActiveRecord; `pg_search` queda para cuando se migre a PostgreSQL)*
- **Requerimientos No Funcionales del SRS**:
  - **RNF-01 (Seguridad y LFPDPPP)**, **RNF-02 (Escalabilidad)**, **RNF-03 (Background Jobs)** *(Sidekiq/Redis configurados)*, **RNF-04 (Usabilidad UI/UX)**, **RNF-05 (Respaldos)**, **RNF-06 (API REST para integración con CRMs)** *(✅ Implementado: `/api/v1` con token Bearer por usuario, guardado como SHA-256)*.

---

## 3. Arquitectura de Base de Datos y Modelos Implementados
- **`Firm` (Despachos / Firmas)**: Nombre, RFC. Todo usuario pertenece a un despacho (se crea uno personal al registrarse) y documentos/plantillas se aíslan por despacho.
- **`User` (Usuarios / Abogados / Personal)**: Integrado con Devise (`email`, `encrypted_password`, `first_name`, `last_name`, `role`), asociado a una `Firm`.
- **`Document` (Documentos Legales)**: Título, cliente, tipo de trámite, estado (`draft`, `processing`, `completed`, `error`, `validated`), texto OCR (`extracted_text`), error de OCR, datos detectados/capturados en `metadata` (JSON). Archivo vía Active Storage.
- **`Template` (Plantillas de Documentos)**: Nombre, cuerpo con marcadores `{{campo}}`, `field_mappings` (marcador → campo del documento), archivo original. Sin `firm` = biblioteca legal compartida (solo lectura).
- **`Version` (Auditoría PaperTrail - RF-06)**: Rastro histórico de cambios, consultas y descargas con el usuario responsable (`whodunnit`).
- **`IssuedDocument` (RF-03)**: PDF emitido con folio (`token`), hash `sha256` y nombre del formato. Se valida en `/verificar/:token`.
- **`Plan` / `MonthlyUsage` (RF-04)**: `Firm#plan` y `Firm#billing_cycle`; el contador mensual no baja al borrar documentos. Solo el rol `admin` cambia el plan (quien se registra y crea su despacho queda como admin).
- **`User#api_token_digest` (RNF-06)**: el token se muestra una sola vez en la página “API”.

### Servicios y jobs
- `app/services/ocr_extractor.rb`: PDF con capa de texto (`pdftotext`), PDF escaneado/imágenes (`pdftoppm` + `tesseract`), Word `.docx` y texto.
- `app/services/legal_fields.rb`: catálogo de datos jurídicos (nombre, contraparte, RFC, CURP, fecha, monto, expediente, escritura, notaría, domicilio, C.P.): extracción, corrección de errores típicos de OCR en RFC/CURP y validación de formato.
- `app/services/template_filler.rb`: autollenado de plantillas; marca faltantes como `[CAMPO]` y reporta datos inválidos.
- `app/services/document_export.rb`: exporta el autollenado a PDF (Prawn, con pie de QR al emitir) y Word `.docx` (rubyzip).
- `app/controllers/api/v1/`: API REST (documentos: listar/filtrar, ver, crear con archivo, actualizar datos, autollenar; plantillas).
- `app/jobs/document_ocr_job.rb` / `template_text_job.rb`: procesamiento en segundo plano (RNF-03). Los datos capturados a mano nunca se sobrescriben.

### Dependencias del sistema
- `poppler` (pdftotext, pdftoppm), `tesseract`, `unzip`. **Instalar el idioma español**: `sudo pacman -S tesseract-data-spa` (sin él se usa el primer idioma disponible y baja la precisión). Se puede forzar con `OCR_LANG`.
- Gema `json` fijada a `~> 2.16`: la 3.x rompe la lectura de columnas JSON en Rails 8.1.

## 4. Cómo Correr el Proyecto

Para levantar el entorno de desarrollo localmente en este sistema (Arch Linux con Ruby / Rails):

1. **Instalar dependencias de Ruby**:
   ```bash
   bundle install
   ```

2. **Configurar y migrar la base de datos**:
   ```bash
   bin/rails db:prepare
   ```
   *(Esto creará la base de datos de desarrollo y ejecutará las migraciones)*

3. **Iniciar el servidor de desarrollo**:
   Puedes utilizar el script unificado de Rails (que arranca Puma, procesamiento en segundo plano, etc.):
   ```bash
   bin/dev
   ```
   O bien directamente con Rails:
   ```bash
   bin/rails server
   ```
   El servidor estará disponible por defecto en `http://localhost:3000`.

4. **Ejecutar pruebas (Test suite)**:
   ```bash
   bin/rails test
   ```

---

## 5. Cronograma de Fases (Diagrama de Gantt)

Fechas tomadas de `Diagrama de Gantt_digitalizacion.pdf`.

| Fase / Actividad | Periodo en Gantt | Estado (al 26 de Oct 2026) |
| :--- | :--- | :--- |
| **Planificación** | | |
| - Levantamiento de requerimientos (SRS & Canvas) | 1 - 15 sep | ✅ **Completado** |
| - Planificación de fases | 1 - 15 sep | ✅ **Completado** |
| - Asesoría | 1 - 30 sep | ✅ **Completado** |
| **Desarrollo** | | |
| - Implementar OCR (RF-01) | 16 - 30 sep | ✅ **Completado** (falta instalar `tesseract-data-spa` en el servidor) |
| - Programar módulo 1: página/software (RF-05, RF-06, RF-07) | 1 - 31 oct | ✅ **Completado** (ajustes menores hasta el 31 oct) |
| - Programar módulo 2: lógica de autollenado (RF-02) | 1 - 31 oct | ✅ **Completado** (ajustes menores hasta el 31 oct) |
| **Pruebas** | | |
| - Testear módulo 1 | 16 - 31 oct | 🔄 **En curso**: 76 pruebas automatizadas en verde; falta prueba manual con documentos reales |
| - Testear módulo 2 | 1 - 15 nov | ⏳ **Pendiente** (adelantado: pruebas unitarias de autollenado y validación ya existen) |
| **Despliegue / Entrega** | | |
| - Desplegar módulo 1 | 1 - 15 nov | ⏳ **Pendiente** |
| - Desplegar módulo 2 | 16 - 30 nov | ⏳ **Pendiente** |
| - Entregar a cliente | 16 - 30 nov | ⏳ **Pendiente** |
| - Cerrar contrato | 16 nov - 15 dic | ⏳ **Pendiente** |
| **Mantenimiento** | | |
| - Mantenimiento correctivo | 1 - 15 dic | ⏳ **Pendiente** |
| - Mantenimiento preventivo | 1 - 15 dic | ⏳ **Pendiente** |

---

## 6. Features Pendientes (Backlog detallado según SRS y Gantt)

1. **Cierre de octubre (Testear módulo 1)**:
   - Prueba manual con expedientes escaneados reales y ajuste de patrones en `LegalFields`.
   - Instalar `tesseract-data-spa` en desarrollo y servidor.

2. **Noviembre - Diciembre**:
   - **Testear módulo 2** (1-15 nov): pruebas de aceptación del autollenado con plantillas reales de despachos.
   - **Desplegar módulos 1 y 2** con Kamal: PostgreSQL, almacenamiento S3 y adaptador de cola (Solid Queue o Sidekiq) en producción.
   - ~~RF-03 hash SHA-256 + QR~~ ✅ (28 oct). Pendiente: firma electrónica avanzada (FIEL / DocuSign).
   - ~~RF-04 planes y cobro por volumen~~ ✅ (28 oct). Pendiente: pasarela de pago (Stripe / Conekta / Mercado Pago) y facturación CFDI.
   - ~~RNF-06 API REST~~ ✅ (28 oct).
   - ~~Autollenado en Word/PDF nativo~~ ✅ (28 oct).
   - Producción: definir servidor, registro de imágenes y dominio en `config/deploy.yml`, y configurar el host público para que las URLs del QR apunten al dominio real.

## 7. Worktrees y Sesiones de Desarrollo

- **Worktrees**:
  - `dev-ocr`: Worktree para desarrollo del motor OCR (RF-01).
  - `dev-autofill`: Worktree para desarrollo del módulo de autollenado (RF-02).
  - `dev-ui`: Worktree para desarrollo de interfaces (RF-05, RF-07).

- **Sesiones de Desarrollo**:
  - `ses-ocr-integration`: Sesión para integración de OCR.
  - `ses-autofill-logic`: Sesión para desarrollo de lógica de autollenado.
  - `ses-ui-development`: Sesión para desarrollo de interfaces.
