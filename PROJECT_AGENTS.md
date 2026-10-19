# PROJECT_AGENTS.md - Estado y Seguimiento del Proyecto (Digitalización y Autollenado Documental)

Este documento sirve como registro oficial y guía para agentes de IA que accedan al proyecto, manteniendo el estado actual, la arquitectura implementada, el cronograma basado en el Diagrama de Gantt y las tareas pendientes.

## 1. Información General del Proyecto
- **Nombre**: Digitalización y Autollenado Documental (`legal-docs-aps`)
- **Periodo del Cronograma**: 1 de septiembre al 15 de diciembre (2026)
- **Fecha actual de referencia**: 19 de octubre de 2026
- **Stack Tecnológico**: 
  - **Framework**: Ruby on Rails 8.1
  - **Autenticación**: Devise (usuarios, roles, relación con Firmas/Despachos)
  - **Base de Datos**: SQLite (desarrollo/test) con Active Record
  - **Gestión de Archivos**: Active Storage
  - **Control de Versiones y Auditoría**: PaperTrail (tabla `versions`)
  - **Búsqueda Avanzada**: `pg_search`
  - **Background Jobs / Cola**: Sidekiq / Solid Queue, Redis
  - **Contenedores y Despliegue**: Docker, Kamal, Thruster, Puma

---

## 2. Arquitectura de Base de Datos y Modelos Implementados
- **`Firm` (Despachos / Firmas)**: Nombre, RFC.
- **`User` (Usuarios / Abogados / Personal)**: Integrado con Devise (`email`, `encrypted_password`, `first_name`, `last_name`, `role`), asociado a una `Firm`.
- **`Document` (Documentos Legales)**: Título, estado (`status`), metadatos JSON (`metadata`), asociado a `Firm` y `User`. Utiliza Active Storage para archivos adjuntos.
- **`Template` (Plantillas de Documentos)**: Nombre, asociado a una `Firm`.
- **`Version` (Auditoría PaperTrail)**: Rastro histórico de cambios en los registros.

---

## 3. Cronograma de Fases (Diagrama de Gantt)

| Fase / Actividad | Duración en Gantt | Estado Actual (al 19 de Oct 2026) |
| :--- | :--- | :--- |
| **Planificación** | | |
| - Levantamiento de requerimientos | 1 - 15 sep | ✅ **Completado** |
| - Planificación de fases | 1 - 15 sep | ✅ **Completado** |
| - Asesoría | 1 sep - 15 dic (transversal) | 🔄 **En curso** |
| **Desarrollo** | | |
| - Estructura Base y Modelos (Rails 8, Devise, DB) | Sep | ✅ **Completado** (Adelantado / Implementado) |
| - Implementar OCR | 16 sep - 31 oct | 🔄 **En curso** (Activo actualmente) |
| - Programar módulo 1 (página/software) | 16 sep - 31 oct | 🔄 **En curso** (Activo actualmente) |
| - Programar módulo 2 (lógica de autollenado) | 16 sep - 31 oct | 🔄 **En curso** (Activo actualmente) |
| **Pruebas** | | |
| - Testear módulo 1 | 1 - 15 nov | ⏳ **Pendiente** |
| - Testear módulo 2 | 1 - 15 nov | ⏳ **Pendiente** |
| **Despliegue / Entrega** | | |
| - Desplegar módulo 1 | 16 - 30 nov | ⏳ **Pendiente** |
| - Desplegar módulo 2 | 16 - 30 nov | ⏳ **Pendiente** |
| - Entregar a cliente | 1 - 15 dic | ⏳ **Pendiente** |
| - Cerrar contrato | 1 - 15 dic | ⏳ **Pendiente** |
| **Mantenimiento** | | |
| - Mantenimiento correctivo | 1 - 15 dic (y posterior) | ⏳ **Pendiente** |
| - Mantenimiento preventivo | 1 - 15 dic (y posterior) | ⏳ **Pendiente** |

---

## 4. Features Pendientes (Backlog restante según Gantt)

1. **Finalización de Programación de Módulos (Octubre)**
   - **Módulo 1**: Creación de controladores, vistas y flujos de interfaz de usuario para gestión de documentos y plantillas.
   - **Módulo 2**: Implementación de la lógica de procesamiento y autollenado documental basado en plantillas y metadatos.
   - **OCR**: Conexión y procesamiento final de reconocimiento óptico de caracteres para extracción de datos en documentos escaneados.

2. **Fase de Pruebas (1 - 15 de Noviembre)**
   - Pruebas unitarias y de integración para el Módulo 1 (Controllers, Views, System tests con Capybara).
   - Pruebas unitarias para la lógica del Módulo 2 y extracción OCR.

3. **Fase de Despliegue y Entrega (16 de Noviembre - 15 de Diciembre)**
   - Configuración final de despliegue mediante Kamal / Docker.
   - Despliegue en producción de ambos módulos.
   - Entrega formal y aceptación por parte del cliente.
   - Cierre de contrato.

4. **Fase de Mantenimiento (A partir de Diciembre)**
   - Configuración de protocolos de soporte correctivo y preventivo.
