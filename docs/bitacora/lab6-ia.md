He leído la política de uso de IA de la asignatura.

# Declaración de uso de IA · Lab 6 · 

## Entrada 1
- **Herramienta:** Gemini
- **Prompt (literal, copiado tal cual):**
```text
Con este readme que tengo mi analisis sobre el sintoma, el contexto, la evidencia e hipotesis,ayudame en la seccion de actuar para finalizar la sesion de APP_ACADEMIA y que se pueda liberar el bloqueo.
```

- **Código recibido (el fragmento, o la ruta del archivo donde está):**
```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SYSTEM KILL SESSION '68,42887' IMMEDIATE;
```
- **Dónde lo usé (parte, script o pregunta):** paso 5
- **Propósito (para qué lo necesitaba):** Confirmar la sintaxis exacta para terminar la sesión bloqueadora dentro de la PDB usando el wrapper `sysdba.sh`.
- **Qué hace (con mis palabras; línea a línea si es SQL corto):** 
  - Línea 1 (`ALTER SESSION SET CONTAINER = FREEPDB1;`): cambia el contexto de la sesión administrativa desde la raíz hacia la base conectable FREEPDB1, que es donde existe la sesión bloqueadora.
  - Línea 2 (`ALTER SYSTEM KILL SESSION '68,42887' IMMEDIATE;`): finaliza de forma inmediata la sesión de APP_ACADEMIA, forzando el rollback de su transacción pendiente y liberando el bloqueo sobre ACA_ESTUDIANTES.
- **Evidencia de ejecución (archivo de docs/bitacora/lab6/evidencia con mi cabecera):** 
docs/bitacora/lab6/evidencia/script/20261125T235030Z_08-inc1-actuar.script.log

## Entrada 2
- **Herramienta:** Gemini
- **Prompt (literal, copiado tal cual):**
```text
Con este readme que ya tengo de los tres incidentes resueltos, resumeme la informacion para agregar la seccion de postmortems sin culpables siguiendo la plantilla de la seccion 5.9.5. con mis ideas y mis palabras, es reescritura, no generacion de texto.
```
- **Código recibido (el fragmento, o la ruta del archivo donde está):**
```markdown
docs/bitacora/lab6-guardia.md (sección Postmortems sin culpables para INC-601, INC-602 e INC-603)
```
- **Dónde lo usé (parte, script o pregunta):** Sección 5.9.5 (I.5 — El postmortem sin culpables) al final de `docs/bitacora/lab6-guardia.md`.
- **Propósito (para qué lo necesitaba):** Sintetizar el diagnóstico que yo hice, causa raíz sin culpables, intervención mínima, validación y acción preventiva de los tres incidentes atendidos en el turno en un formato estructurado.
- **Qué hace (con mis palabras; línea a línea si es SQL corto):** 
  - No es código SQL ejecutable, sino documentación operativa en Markdown que resume cada incidente (INC-601, INC-602 e INC-603) enfocándose en las fallas técnicas del sistema y las mejoras preventivas para evitar que se repitan con lo que yo ya habia identificado.
- **Evidencia de ejecución (archivo de docs/bitacora/lab6/evidencia con mi cabecera):** 
docs/bitacora/lab6/evidencia/script/20261125T235148Z_08-inc1-diagnostico-despues.script.log, docs/bitacora/lab6/evidencia/script/20261126T003510Z_08-inc2-diagnostico-despues.script.log y docs/bitacora/lab6/evidencia/script/20261126T005040Z_08-inc3-diagnostico-despues.script.log

## Entrada 3
- **Herramienta:** Gemini
- **Prompt (literal, copiado tal cual):**
```text
ayudame a generar una pequeña descripcion y un indice para darle orden a todas las preguntas que he ido respondiendo paso a paso en el laboratorio, arregla problemas de ortografia y de tipado si es necesario
```
- **Código recibido (el fragmento, o la ruta del archivo donde está):**
```markdown
Encabezado, descripción inicial, índice con enlaces internos y corrección ortográfica/de tipado en `docs/bitacora/lab6-respuestas.md`.
```
- **Dónde lo usé (parte, script o pregunta):** Estructura general, índice y revisión de estilo en `docs/bitacora/lab6-respuestas.md` (secciones de Prácticas SRE, Preguntas de comprobación y Preguntas tipo examen).
- **Propósito (para qué lo necesitaba):** Darle estructura navegable al documento final de respuestas mediante un encabezado descriptivo e índice por secciones, además de corregir errores tipográficos y de formato en las respuestas ya redactadas.
- **Qué hace (con mis palabras; línea a línea si es SQL corto):** 
  - No es código SQL ejecutable, sino una mejora estructural y de formato en Markdown que organiza el documento de respuestas del laboratorio en bloques temáticos navegables y limpia erratas de escritura sin alterar las cifras ni los resultados obtenidos en las evidencias.
- **Evidencia de ejecución (archivo de docs/bitacora/lab6/evidencia con mi cabecera):** `docs/bitacora/lab6-respuestas.md` (con referencias cruzadas a los logs de `docs/bitacora/lab6/evidencia/script/`).

## Entrada Example
- **Herramienta:** 
- **Prompt (literal, copiado tal cual):**
```text

```
- **Código recibido (el fragmento, o la ruta del archivo donde está):**
```sql

```
- **Dónde lo usé (parte, script o pregunta):** 
- **Propósito (para qué lo necesitaba):** 
- **Qué hace (con mis palabras; línea a línea si es SQL corto):** 
- **Evidencia de ejecución (archivo de docs/bitacora/lab6/evidencia con mi cabecera):** 
