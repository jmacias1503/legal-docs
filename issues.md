# Issues - Tareas Pendientes para DigitalLaw (Digitalización y Autollenado Documental)

Este documento lista las tareas pendientes organizadas por fase, alineadas con el SRS y el cronograma del Gantt. Cada issue incluye:
- **Título descriptivo**
- **Descripción detallada**
- **Requerimiento SRS asociado**
- **Prioridad** (Alta/Media/Baja)
- **Estimación de tiempo**
- **Dependencias** (si aplica)

## Estado al 28 de octubre de 2026

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
