# Issues - Tareas Pendientes para DigitalLaw (Digitalización y Autollenado Documental)

Este documento lista las tareas pendientes organizadas por fase, alineadas con el SRS y el cronograma del Gantt. Cada issue incluye:
- **Título descriptivo**
- **Descripción detallada**
- **Requerimiento SRS asociado**
- **Prioridad** (Alta/Media/Baja)
- **Estimación de tiempo**
- **Dependencias** (si aplica)

## Estado al 10 de noviembre de 2026

| Issue | Estado | Dónde |
| :--- | :--- | :--- |
| #1 OCR jurídico | ✅ Hecho | `app/services/ocr_extractor.rb`, `app/services/legal_fields.rb` |
| #2 OCR asíncrono | ✅ Hecho (ActiveJob); falta elegir adaptador de cola en producción | `app/jobs/document_ocr_job.rb` |
| #3 Vistas de documentos | ✅ Hecho | `app/views/documents/` |
| #4 Plantillas con mapeo de campos | ✅ Hecho | `app/views/templates/`, `Template#field_mappings` |
| #5 Búsqueda avanzada | ✅ Hecho con ActiveRecord (SQLite); `pg_search` al migrar a PostgreSQL | `Document.filter_by` |
| #6 Motor de autollenado | ✅ Hecho | `app/services/template_filler.rb` |
| #7 Validación de datos extraídos | ✅ Hecho | `LegalFields.invalid`, acción "Validar datos" |
| #8 Pruebas módulo 1 | 🔄 Automatizadas listas; falta prueba manual | `test/controllers/`, `test/models/` |
| #9 Pruebas módulo 2 | 🔄 Unitarias adelantadas; aceptación en noviembre | `test/services/`, `test/jobs/` |
| #10 Despliegue con Kamal | ⏳ Pendiente: faltan servidor, registro y dominio | `config/deploy.yml` |
| #11 Suscripciones SaaS | ✅ Planes, uso mensual y excedente por volumen; falta pasarela de pago | `app/models/plan.rb`, `SubscriptionsController` |
| #16 Verificación SHA-256 + QR (RF-03) | ✅ Hecho; FIEL/DocuSign pendiente | `IssuedDocument`, `/verificar/:folio` |
| #17 API REST (RNF-06) | ✅ Hecho | `app/controllers/api/v1/` |
| #18 Descarga PDF/Word del autollenado | ✅ Hecho | `app/services/document_export.rb` |
| #19 Bitácora de accesos (RF-06) | ✅ Consultas, descargas, validación y emisión | `Document#log_event!` |
| #12 – #15 | ⏳ Pendientes según Gantt (noviembre – diciembre) | |
| #20 Autollenado sobre el Word original (RF-02, RF-05) | ✅ Hecho: llena el .docx original (cuerpo, encabezados, pies, notas), con respaldo al Word genérico si el archivo está dañado o excede límites. Limitación: los marcadores que solo existen en el Word no se pueden mapear en el formulario (solo se listan los del cuerpo) | `app/services/template_filler.rb` |
| #21 Pruebas de aceptación módulo 2 | ✅ Hecho | `test/integration/autofill_acceptance_test.rb` |
| #22 Configuración de producción (PostgreSQL, S3, Solid Queue) | ✅ Hecho (configuración lista); falta probar contra un PostgreSQL real antes del primer despliegue | `config/`, `db/*_schema.rb` |
| #23 Kamal: servidor, registro, dominio y host público | ⏳ Bloqueado: faltan servidor, registro y dominio | `config/deploy.yml` |
| #24 Respaldos automáticos (RNF-05) | ✅ Hecho; faltan pruebas reales contra PostgreSQL y configurar el bucket | `app/jobs/database_backup_job.rb` |
| #25 Pasarela de pago y facturación CFDI (RF-04) | ⏳ Pendiente de decisión de negocio/proveedor | |
| #26 Firma electrónica avanzada FIEL/DocuSign (RF-03) | ⏳ Pendiente de decisión de negocio/proveedor | |
| #27 Límite de tamaño en la verificación pública (RNF-01) | ✅ Hecho; el tope real de subida queda para el despliegue (#23) | `app/controllers/verifications_controller.rb` |
| #28 Datos del cliente en el nombre de la plantilla emitida (RNF-01, LFPDPPP) | ✅ Hecho | `app/models/issued_document.rb`, `db/migrate/20261110120000_add_library_template_to_issued_documents.rb` |

> Nota: la prueba manual del módulo 1 con expedientes reales (#8) la hace el equipo.

---

## 1. Implementación del Motor OCR (RF-01)

### Issue #1: Integración de OCR Jurídico
- **Descripción**: Desarrollar un motor de reconocimiento de texto optimizado para jerga jurídica, capaz de extraer datos estructurados de documentos escaneados.
- **SRS**: RF-01 (Digitalización y OCR)
- **Prioridad**: Alta
- **Estimación**: 3 semanas
- **Dependencias**: Configuración de Active Storage para almacenamiento de imágenes/PDF.

### Issue #2: Procesamiento Asíncrono de OCR
- **Descripción**: Configurar Sidekiq/Redis para manejar el procesamiento pesado de OCR en segundo plano, evitando bloqueos en el servidor web.
- **SRS**: RF-01, RNF-03 (Background Jobs)
- **Prioridad**: Alta
- **Estimación**: 2 semanas
- **Dependencias**: Issue #1 (OCR Jurídico).

---

## 2. Módulo 1: Interfaz y Gestión de Documentos (RF-05, RF-07)

### Issue #3: Vistas de Gestión de Documentos
- **Descripción**: Crear vistas Hotwire para subir, visualizar y gestionar documentos (listado, detalles, estado).
- **SRS**: RF-05 (Gestión de Plantillas), RF-07 (Búsqueda Avanzada)
- **Prioridad**: Alta
- **Estimación**: 2 semanas
- **Dependencias**: Modelo `Document` y Active Storage.

### Issue #4: Interfaz de Plantillas Personalizadas
- **Descripción**: Desarrollar un formulario para subir, editar y configurar plantillas (PDF/Word) con mapeo de campos.
- **SRS**: RF-05 (Gestión de Plantillas)
- **Prioridad**: Alta
- **Estimación**: 2 semanas
- **Dependencias**: Modelo `Template`.

### Issue #5: Motor de Búsqueda Avanzada
- **Descripción**: Implementar filtros de búsqueda por metadatos (fecha, cliente, tipo de trámite, estado) utilizando `pg_search`.
- **SRS**: RF-07 (Búsqueda Avanzada)
- **Prioridad**: Media
- **Estimación**: 1 semana
- **Dependencias**: Modelo `Document` y vistas de gestión.

---

## 3. Módulo 2: Lógica de Autollenado (RF-02)

### Issue #6: Motor de Autollenado Documental
- **Descripción**: Desarrollar la lógica para llenar automáticamente plantillas jurídicas con datos extraídos por OCR (Issue #1).
- **SRS**: RF-02 (Autollenado de Formatos)
- **Prioridad**: Alta
- **Estimación**: 3 semanas
- **Dependencias**: Issue #1 (OCR Jurídico), Issue #4 (Plantillas).

### Issue #7: Validación de Datos Extraídos
- **Descripción**: Implementar reglas de validación para garantizar la precisión de los datos autollenados.
- **SRS**: RF-02
- **Prioridad**: Media
- **Estimación**: 1 semana
- **Dependencias**: Issue #6 (Autollenado).

---

## 4. Pruebas (Noviembre)

### Issue #8: Pruebas Unitarias de Módulo 1
- **Descripción**: Escribir pruebas unitarias para los controladores y vistas del Módulo 1 (subida de documentos, gestión de plantillas).
- **SRS**: RF-05, RF-07
- **Prioridad**: Alta
- **Estimación**: 1 semana
- **Dependencias**: Finalización de Issues #3 y #4.

### Issue #9: Pruebas Unitarias de Módulo 2
- **Descripción**: Escribir pruebas unitarias para la lógica de autollenado y validación de datos.
- **SRS**: RF-02
- **Prioridad**: Alta
- **Estimación**: 1 semana
- **Dependencias**: Finalización de Issues #6 y #7.

---

## 5. Despliegue y Entrega (Noviembre - Diciembre)

### Issue #10: Configuración de Despliegue con Kamal
- **Descripción**: Configurar Kamal para despliegue en producción con Docker y PostgreSQL.
- **SRS**: RNF-02 (Escalabilidad Cloud)
- **Prioridad**: Alta
- **Estimación**: 2 semanas
- **Dependencias**: Finalización de Issues #8 y #9 (Pruebas).

### Issue #11: Módulo de Suscripciones SaaS
- **Descripción**: Desarrollar el módulo de gestión de suscripciones (planes mensuales/anuales y cobro por volumen).
- **SRS**: RF-04 (Sistema de Suscripciones SaaS)
- **Prioridad**: Alta
- **Estimación**: 2 semanas
- **Dependencias**: Issue #10 (Despliegue).

### Issue #12: Entrega y Validación Piloto
- **Descripción**: Ejecutar la entrega formal al cliente y validación en despachos piloto.
- **SRS**: RF-04, RF-05, RF-07
- **Prioridad**: Alta
- **Estimación**: 1 semana
- **Dependencias**: Issues #10 y #11 (Despliegue y SaaS).

### Issue #13: Cierre de Contrato
- **Descripción**: Finalizar los procesos administrativos y cerrar el contrato con el cliente.
- **SRS**: RF-04
- **Prioridad**: Alta
- **Estimación**: 1 semana
- **Dependencias**: Issue #12 (Entrega).

---

## 6. Mantenimiento (Posterior a Diciembre)

### Issue #14: Configuración de Mantenimiento Correctivo
- **Descripción**: Establecer protocolos para soporte técnico y corrección de errores.
- **SRS**: RNF-05 (Respaldos)
- **Prioridad**: Media
- **Estimación**: 1 semana
- **Dependencias**: Issue #13 (Cierre de Contrato).

### Issue #15: Mantenimiento Preventivo
- **Descripción**: Programar tareas de actualización de plantillas y seguridad.
- **SRS**: RF-05, RNF-01 (Seguridad)
- **Prioridad**: Baja
- **Estimación**: 1 semana
- **Dependencias**: Issue #14 (Mantenimiento Correctivo).

---

## 7. Mejoras posteriores y producción (Noviembre en adelante)

### Issue #20: Autollenado sobre el Word original
- **Descripción**: Hoy una plantilla subida en .docx se convierte a texto plano con OCR y se pierde el formato; el PDF/Word exportado es genérico. Nuevo comportamiento: cuando la plantilla tiene un .docx adjunto, los marcadores `{{campo}}` se reemplazan dentro del propio .docx (`word/document.xml`, encabezados y pies de página), incluso si Word los partió en varios fragmentos (runs), conservando el formato. Las plantillas de texto o PDF siguen el flujo de texto plano.
- **SRS**: RF-02 (Autollenado de Formatos), RF-05 (Gestión de Plantillas)
- **Prioridad**: Alta
- **Estimación**: Por definir
- **Estado**: ✅ Hecho
- **Entregado**: llena el .docx original (cuerpo, encabezados, pies y notas), con respaldo al Word genérico si el archivo está dañado o excede límites. Limitación conocida: los marcadores que solo existen en el Word no se pueden mapear en el formulario (solo se listan los del cuerpo).
- **Dependencias**: Ninguna.

### Issue #21: Pruebas de Aceptación del Módulo 2
- **Descripción**: Continúa el Issue #9 (pruebas unitarias). Escribir pruebas de aceptación del módulo 2: autollenado completo, con datos faltantes e inválidos, mapeos de campos y descargas PDF/Word, incluyendo el Word original.
- **SRS**: RF-02
- **Prioridad**: Alta
- **Estimación**: Por definir
- **Estado**: ✅ Hecho
- **Entregado**: 14 pruebas de integración en `test/integration/autofill_acceptance_test.rb`. Sin cubrir: el contenido del PDF (no hay gema para leer PDF).
- **Dependencias**: Issue #20 (Autollenado sobre el Word original), ya hecho.

### Issue #22: Configuración de Producción
- **Descripción**: Configurar PostgreSQL como base de datos, almacenamiento tipo S3 para Active Storage y Solid Queue como cola de trabajos. Solid Queue funciona sobre PostgreSQL, sin Redis.
- **SRS**: RNF-02 (Escalabilidad Cloud), RNF-03 (Background Jobs)
- **Prioridad**: Alta
- **Estimación**: Por definir
- **Estado**: ✅ Hecho (configuración lista); falta probar contra un PostgreSQL real antes del primer despliegue.
- **Pendientes menores**:
  - ✅ Resuelto: error 500 con parámetros no-texto; `filter_by` ignora los parámetros que no son texto y la API ignora un `page` no numérico.
  - ✅ Resuelto: se quitó el paquete apt `sqlite3` de la imagen Docker de producción. Si el build o el arranque de la imagen reclama `libsqlite3`, revertir esa línea del Dockerfile (suposición no comprobada con un build real).
  - ✅ Resuelto: `bin/docker-entrypoint` valida `DB_HOST` y `DIGITALLAW_DATABASE_PASSWORD` y muestra un error claro si faltan.
  - Abierto: probar `db:prepare` contra un PostgreSQL real.
- **Dependencias**: Ninguna.

### Issue #23: Kamal: Servidor, Registro, Dominio y Host Público
- **Descripción**: Refina el Issue #10. Definir servidor, registro de imágenes y dominio, y configurar el host público usado en las URLs de los códigos QR de verificación.
- **SRS**: RNF-02 (Escalabilidad Cloud), RF-03 (Verificación con QR)
- **Prioridad**: Alta
- **Estimación**: Por definir
- **Estado**: ⏳ Bloqueado: faltan servidor, registro de imágenes y dominio.
- **Dependencias**: Issue #22 (Configuración de producción).

### Issue #24: Respaldos Automáticos
- **Descripción**: Configurar respaldos automáticos de la base de datos y de los archivos almacenados.
- **SRS**: RNF-05 (Respaldos)
- **Prioridad**: Media
- **Estimación**: Por definir
- **Estado**: ✅ Hecho
- **Entregado**: job diario a las 3:00 UTC (`app/jobs/database_backup_job.rb`) que ejecuta `pg_dump` y sube el respaldo a S3 (`backups/`); restauración y retención documentadas en el README.
- **Pendientes**:
  - Probar un respaldo y una restauración reales contra PostgreSQL antes del primer despliegue (`pg_dump` no está instalado en desarrollo).
  - Configurar la regla de ciclo de vida (~30 días) y el versionado del bucket.
  - El cliente `pg_dump` de la imagen es PG 17: el servidor debe ser ≤ 17.
  - Límite de 5 GB por subida simple.
- **Dependencias**: Issue #22 (Configuración de producción), ya hecho.

### Issue #25: Pasarela de Pago y Facturación CFDI
- **Descripción**: Integrar una pasarela de pago y facturación CFDI para las suscripciones (complementa el Issue #11).
- **SRS**: RF-04 (Sistema de Suscripciones SaaS)
- **Prioridad**: Media
- **Estimación**: Por definir
- **Estado**: ⏳ Pendiente de decisión de negocio/proveedor
- **Dependencias**: Decisión de negocio y de proveedor.

### Issue #26: Firma Electrónica Avanzada (FIEL/DocuSign)
- **Descripción**: Integrar firma electrónica avanzada (FIEL o DocuSign) a los documentos emitidos (complementa el Issue #16).
- **SRS**: RF-03
- **Prioridad**: Media
- **Estimación**: Por definir
- **Estado**: ⏳ Pendiente de decisión de negocio/proveedor
- **Dependencias**: Decisión de negocio y de proveedor.

### Issue #27: Límite de Tamaño en la Verificación Pública
- **Descripción**: `VerificationsController#create` (`/verificar/:token`, subida pública sin sesión) lee el archivo completo sin límite de tamaño. Hay límite de 20 peticiones por minuto, pero no de tamaño. Rechazar archivos mayores a unos MB.
- **SRS**: RNF-01 (Seguridad)
- **Prioridad**: Media
- **Estimación**: Por definir
- **Estado**: ✅ Hecho; el tope real de subida queda pendiente (ver Pendiente).
- **Entregado**: `VerificationsController#create` rechaza con 422 los archivos mayores a 10 MB sin leerlos y los parámetros que no son archivo; la lectura del archivo está acotada.
- **Pendiente**: Rack guarda el cuerpo multipart en disco antes de llegar al controlador (`Rack::MethodOverride` lee los parámetros), así que el tope solo acota lo que la aplicación lee en memoria. Sin `Content-Length` (transferencia por partes) tampoco hay protección temprana. Un tope real requiere un middleware de Rack antes de `Rack::MethodOverride` o un límite en el proxy (no global, porque limitaría la subida de documentos). Definir al resolver el despliegue (#23).
- **Dependencias**: Ninguna.

### Issue #28: Datos del Cliente en el Nombre de la Plantilla Emitida
- **Descripción**: La página pública `/verificar/:token` muestra el nombre de la plantilla (texto libre escrito por el despacho), que podría contener datos de un cliente. Decidir si se muestra solo para plantillas de la biblioteca o si se advierte al despacho.
- **SRS**: RNF-01 (Seguridad), LFPDPPP
- **Prioridad**: Media
- **Estimación**: Por definir
- **Estado**: ✅ Hecho
- **Entregado**: `/verificar` muestra el nombre del formato solo si es de la biblioteca legal; si no, "Formato personalizado del despacho". Se guarda en la columna `library_template` de `issued_documents` (migración `20261110120000_add_library_template_to_issued_documents.rb`). Los documentos emitidos antes del cambio muestran el nombre genérico. La página pública sigue mostrando nombre del despacho, fecha y huella (intencional).
- **Dependencias**: Ninguna.
