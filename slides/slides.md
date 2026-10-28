---
theme: default
title: Avances DigitalLaw
colorSchema: light
class: text-center
---

# Avances en DigitalLaw
## Digitalización y Autollenado Documental

Equipo Threno (UAQ) · Corte al 26 de octubre de 2026

---

# Contexto del Proyecto

- **Nombre**: DigitalLaw
- **Equipo**: Threno (UAQ)
- **Objetivo**: Digitalizar expedientes físicos y autollenar formatos legales para despachos, notarías y administradores.
- **Stack**: Ruby on Rails 8.1 (Hotwire), Devise, Active Storage, PaperTrail, Tesseract OCR, Solid Queue / Sidekiq, Kamal.

---
zoom: 0.85
---

# Estado del Cronograma (Gantt)

| Actividad | Periodo | Estado |
| :--- | :--- | :--- |
| Requerimientos · Planificación · Asesoría | 1 – 30 sep | <span class="badge ok">Completado</span> |
| Implementar OCR | 16 – 30 sep | <span class="badge ok">Completado</span> |
| Programar módulo 1 (página/software) | 1 – 31 oct | <span class="badge ok">Completado</span> |
| Programar módulo 2 (lógica de autollenado) | 1 – 31 oct | <span class="badge ok">Completado</span> |
| Testear módulo 1 | 16 – 31 oct | <span class="badge run">En curso</span> 46 pruebas automatizadas en verde |
| Testear módulo 2 | 1 – 15 nov | <span class="badge todo">Pendiente</span> adelantado: pruebas unitarias listas |
| Desplegar módulos 1 y 2 · Entrega | nov | <span class="badge todo">Pendiente</span> |
| Cerrar contrato · Mantenimiento | nov – dic | <span class="badge todo">Pendiente</span> |

**El proyecto va al corriente con el cronograma.**

---
zoom: 0.9
---

# Requerimientos del SRS Cubiertos

| Requerimiento | Implementación |
| :--- | :--- |
| **RF-01** Digitalización y OCR | PDF, imágenes, Word y texto → texto + datos jurídicos detectados |
| **RF-02** Autollenado de formatos | Plantillas con marcadores <code v-pre>{{campo}}</code> + biblioteca legal |
| **RF-05** Plantillas personalizadas | Subida de formatos y mapeo de campos por despacho |
| **RF-06** Historial de auditoría | Registro de quién creó o modificó cada expediente |
| **RF-07** Búsqueda y filtrado | Texto completo (incluye contenido OCR), cliente, trámite, estado y fechas |
| **RNF-03** Background jobs | El OCR corre en segundo plano, sin bloquear la web |
| **RNF-01** Seguridad | Cada despacho solo ve sus propios documentos y plantillas |

---
layout: two-cols
---

# Acceso al Sistema

- Inicio de sesión y registro con Devise.
- Al registrarse, cada usuario obtiene su propio **despacho**.
- La información queda aislada por despacho.

::right::

<img src="/screenshots/01-login.png" class="rounded shadow mb-3" />
<img src="/screenshots/02-registro.png" class="rounded shadow" />

---

# Módulo 1 · Gestión de Documentos

<img src="/screenshots/03-documentos.png" class="rounded shadow h-100 mx-auto" />

Listado por despacho con estado del procesamiento: *Borrador → Procesando OCR → Datos extraídos → Validado*.

---

# Módulo 1 · Búsqueda y Filtrado (RF-07)

<img src="/screenshots/04-busqueda.png" class="rounded shadow h-90 mx-auto" />

Búsqueda por **"Hidalgo"**: encuentra la carta poder aunque la palabra solo aparezca **dentro del texto escaneado**.

---
layout: two-cols
---

# Carga de Documentos

- Acepta **PDF, imágenes (PNG/JPG/TIFF), Word (.docx) y texto**.
- Al guardar, el OCR se encola en segundo plano (RNF-03).
- Se capturan cliente y tipo de trámite para los filtros.

::right::

<img src="/screenshots/05-nuevo-documento.png" class="rounded shadow" />

---

# OCR Jurídico (RF-01): del Escaneo a Datos

<img src="/screenshots/00-escaneo-original.png" class="rounded shadow h-28 mx-auto mb-2 border" />

<div class="text-center text-2xl">↓</div>

<img src="/screenshots/06-documento-ocr.png" class="rounded shadow h-72 mx-auto" />

---

# Datos que Detecta el OCR

- **Partes**: nombre principal y contraparte (`C. NOMBRE APELLIDO`)
- **Identificadores**: RFC y CURP, con corrección de errores típicos del OCR (`O`↔`0`, `B`↔`8`)
- **Fechas** (`03/10/2026`, `15 de octubre de 2026`) y **montos** (`$12,500.00`)
- **Expediente, escritura y notaría**
- **Domicilio y código postal**

Los datos capturados a mano **nunca se sobrescriben** al reprocesar el OCR.

---
layout: two-cols
---

# Corrección y Validación

- El usuario revisa y corrige los datos detectados.
- Puede agregar campos propios (ej. `precio_renta`).
- **Validar datos** revisa el formato de RFC, CURP, fechas, montos y C.P.

::right::

<img src="/screenshots/08-editar-datos.png" class="rounded shadow h-110" />

---

# Historial de Auditoría (RF-06)

<img src="/screenshots/07-documento-validado.png" class="rounded shadow h-100 mx-auto" />

Cada cambio registra **quién** lo hizo y **cuándo**: el usuario o el sistema (OCR).

---

# Módulo 2 · Plantillas (RF-05)

<img src="/screenshots/11-plantillas.png" class="rounded shadow h-90 mx-auto" />

**Biblioteca legal** compartida (solo lectura) + plantillas propias de cada despacho.

---
layout: two-cols
---

# Mapeo de Campos

- El formato se escribe con marcadores <code v-pre>{{campo}}</code>.
- Si se sube un PDF/Word, su texto se extrae para usarlo como base.
- Cada marcador se asocia a un dato del documento:
  - <code v-pre>{{arrendador}}</code> → Nombre
  - <code v-pre>{{arrendatario}}</code> → Contraparte
  - <code v-pre>{{renta}}</code> → Monto

::right::

<img src="/screenshots/12-plantilla-mapeo.png" class="rounded shadow h-110" />

---

# Módulo 2 · Autollenado (RF-02)

<img src="/screenshots/09-autollenado-completo.png" class="rounded shadow h-90 mx-auto" />

Contrato generado con los datos extraídos del escaneo. Se descarga en `.txt` o se imprime / guarda como PDF.

---

# Autollenado con Datos Faltantes

<img src="/screenshots/10-autollenado-faltantes.png" class="rounded shadow h-90 mx-auto" />

Los campos sin dato se marcan como `[CURP]` y se avisa al usuario para completarlos antes de imprimir.

---
zoom: 0.9
---

# Pruebas (Testear Módulo 1)

- **46 pruebas automatizadas**, 129 verificaciones, todas en verde.
- Cubren: OCR, detección de datos, autollenado, búsqueda, permisos por despacho, auditoría y registro.
- Análisis de seguridad con **Brakeman**: 0 advertencias.
- Estilo de código revisado con **RuboCop**.

### Correcciones encontradas durante las pruebas
- Incompatibilidad de la gema `json 3.x` que rompía los metadatos.
- El registro de usuarios fallaba (faltaban nombre y apellido).
- La auditoría no guardaba al usuario responsable.
- Un usuario sin despacho podía ver plantillas de otros despachos.

---

# Próximos Pasos

## Cierre de octubre
- Prueba manual con expedientes reales de despachos.
- Instalar el modelo de **OCR en español** para mejorar la precisión.

## Noviembre – Diciembre
- **Testear módulo 2** (1 – 15 nov).
- **Desplegar** con Kamal: PostgreSQL, almacenamiento S3 y cola de trabajos.
- **RF-03** verificación con hash SHA-256 / QR · **RF-04** suscripciones SaaS.
- Entrega al cliente, cierre de contrato y mantenimiento.

---

# Conclusiones

- **Progreso**: OCR, gestión documental y autollenado funcionan de punta a punta.
- **Cronograma**: al corriente con el Gantt al 26 de octubre.
- **Riesgos**: precisión del OCR en escaneos de baja calidad y cumplimiento de la LFPDPPP en el despliegue.

---
class: text-center
---

# Preguntas

¿Preguntas o comentarios?

---
class: text-center
---

# ¡Gracias!

Equipo Threno (UAQ)

DigitalLaw — Digitalización y Autollenado Documental

