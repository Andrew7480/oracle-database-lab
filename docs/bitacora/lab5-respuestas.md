# Lab 5 — Respuestas y análisis de evidencias

Documento de trabajo para responder las preguntas de comprobación y desarrollar las prácticas profesionales adicionales del Lab 5. Las respuestas deben estar redactadas con palabras propias y citar la evidencia utilizada, indicando el nombre del archivo y la línea o el valor que lo demuestra.

## Índice

1. [RTO, RPO y SLO](#71-rto-rpo-y-slo)
2. [Retrospectiva sin culpables](#72-retrospectiva-sin-culpables)
3. [Prácticas profesionales](#prácticas-profesionales)
   - [Parte B — BFR de PEDIDO](#parte-b--comprueba-el-bfr-de-pedido-con-tus-propias-manos)
   - [Parte C — Calcular antes de medir](#parte-c--calcula-antes-de-medir)
   - [Parte D — Índice cubriente](#parte-d--el-índice-cubriente-que-sí-pedirías)
   - [Parte E — Dibujar la curva](#parte-e--dibuja-tu-curva)
   - [Parte F — Revisión de código](#parte-f--revisión-de-código-como-en-un-equipo-real)
   - [Parte G — Defender un índice](#parte-g--defiende-tu-propio-índice)
   - [Parte H — Diagnóstico](#parte-h--diagnostica-sin-ver-el-script)
   - [Parte I — MTTR bajo carga](#parte-i--el-mttr-bajo-carga)
   - [Parte K — Dimensionar el redo](#parte-k--dimensiona-el-redo-de-tiendasur)
   - [Parte M — Coste de un DELETE en la FRA](#parte-m--el-coste-de-un-delete-en-tu-fra)
   - [Parte O — Runbook del simulacro D](#parte-o--escribe-el-runbook-del-simulacro-d)
   - [Parte P — Umbral de alerta](#parte-p--un-umbral-que-dispare-una-alerta)
4. [Preguntas de comprobación](#8-preguntas-de-comprobación)
5. [Preguntas tipo examen](#preguntas-tipo-examen)

## 7.1. RTO, RPO y SLO

Un servicio no promete «no fallar nunca»; promete cifras. Para TiendaSur, el objetivo de referencia es **RPO = 0 para pedidos confirmados** y **RTO menor de 15 minutos para un fallo de datafile**. Los simulacros sirven para demostrar el cumplimiento con datos medidos.

| Simulacro | Fallo probado | Resultado medido | RPO | RTO | Evidencia |
|---|---|---|---:|---:|---|
| A | Caída abrupta de instancia | SMON leyó **32 KB** de redo y recuperó **47 bloques**; 102 quedó `EGRESADO` y 103 volvió a `ACTIVO` | 0 para lo confirmado | Recuperación automática; no se cronometró un valor independiente | `20261103T021629Z_14a-caida-instancia.script.log`, líneas 19-32 |
| B | Pérdida de una copia del control file | `ORA-00205` al montar; las otras copias permiten sustituir la ruta dañada | 0 | No se cronometró | `20261103T021702Z_14b-perdida-controlfile.script.log`, líneas 6-27 |
| C | Restauración completa desde copia | Se perdió lo hecho durante **1 s** entre la copia y el fallo; restauración en **77 s** | 1 s de cambios posteriores a la copia | 77 s | `20261103T033304Z_14c-simulacro-restauracion.script.log`, líneas 52-54 |
| D | Pérdida de un datafile de aplicación | Se restauró y recuperó el datafile; la fila 104 quedó `EGRESADO` | 0 | **8 s** de offline a online; **9 s** desde el fallo | `20261103T022359Z_14d-perdida-datafile.script.log`, líneas 51-60 |

El simulacro D cumple el objetivo de referencia: su RPO fue 0 y su RTO de 9 segundos quedó por debajo de 15 minutos. El simulacro C tiene un RPO distinto porque depende de una copia en frío y no de redo archivado aplicado hasta el instante del fallo.

## 7.2. Retrospectiva sin culpables

### Incidente: DML colgado por FRA llena (entorno de laboratorio)

- **Impacto:** una carga quedó bloqueada por `log file switch (archiving needed)`; no hubo pérdida de datos.
- **Detección:** `ORA-19815` avisó que la FRA estaba al **100 %**, con **0 bytes restantes**; después apareció `ORA-19809` (`20261103T020313Z_11-fra-llena.script.log`, líneas 32-33).
- **Causa raíz:** se generó redo con `ARCHIVELOG` activo después de reducir la FRA a **2 MB** para el experimento, aunque el tamaño normal era **4096 MB**.
- **Mitigación:** se liberó espacio mediante RMAN y ARCn pudo reintentar; la FRA volvió a mostrar **8.4 MB usados** (`líneas 39-46`). `RMAN DELETE NOPROMPT ARCHIVELOG ALL` es aceptable solo en laboratorio, no como procedimiento de producción sin validar respaldo y retención.
- **Qué cambia:** el runbook debe alertar al **80 %** de uso y revisar `V$RECOVERY_AREA_USAGE` antes de repetir cargas; la consulta de alerta de este documento dispara a partir de **85 %**.
- **Lección:** el aviso `ORA-19815` llegó antes del bloqueo y no estaba siendo vigilado. La alerta debe notificar al DBA antes de que ARCn no pueda archivar.

## Prácticas profesionales

### Parte B — Comprueba el BFR de PEDIDO con tus propias manos

Calcula, con `DBMS_ROWID.ROWID_BLOCK_NUMBER`, cuántas filas hay en los bloques de `PEDIDO` (mínimo, media y máximo) y compáralo con `NUM_ROWS / BLOCKS`. Agrupa por bloque y calcula `MIN`, `AVG` y `MAX` del recuento. Anota por qué no todos los bloques tienen las mismas filas.

**Respuesta:** La consulta usada es:

```sql
SELECT MIN(filas_bloque), AVG(filas_bloque), MAX(filas_bloque)
FROM (
  SELECT DBMS_ROWID.ROWID_BLOCK_NUMBER(rowid) bloque, COUNT(*) filas_bloque
  FROM tiendasur.pedido
  GROUP BY DBMS_ROWID.ROWID_BLOCK_NUMBER(rowid)
);
```

La estadística global da `NUM_ROWS = 1 000 000` y `BLOCKS = 5 320`, por lo que `NUM_ROWS / BLOCKS = 187.97`, aproximadamente **188 filas por bloque** (`20261103T002048Z_01-perfil-tiendasur.script.log`, líneas 1-7). El mínimo y el máximo no quedaron impresos en el log conservado; no los invento: deben copiarse de la salida de esta consulta. Las diferencias se deben al tamaño real de las filas, cabeceras, `PCTFREE`, bloques parcialmente llenos y al historial de inserciones.

### Parte C — Calcula antes de medir

1. Con los datos de la Parte B, calcula a mano la altura que tendrá `UX_CLI_EMAIL` (100 000 entradas). Supón 30 bytes por entrada de hoja y el mismo factor de ramificación máximo que `IX_PED_CLIENTE`.
2. Comprueba el cálculo con `ANALYZE INDEX tiendasur.ux_cli_email VALIDATE STRUCTURE;` y consulta `INDEX_STATS`.
3. Dibuja con `grafico-indice.sh` el índice `UX_CLI_EMAIL` y explica por qué su mapa tiene esa forma.

**Respuesta:** Con 100 000 entradas y 30 bytes por entrada, la hoja necesita aproximadamente `100000 × 30 / 7996 = 376` bloques útiles. Usando el fan-out máximo de `IX_PED_CLIENTE` (`fo = 543`), la altura esperada es `1 + ceil(log_543(376)) = 2` niveles. La comprobación de `UX_CLI_EMAIL` registra altura **3**, **501 hojas** y **100 000 entradas** (`20261103T010315Z_02-anatomia-indice.script.log`, líneas 6-10); la diferencia se explica por cabeceras, ROWID y espacio reservado. El mapa debe mostrar hojas uniformes, aproximadamente **200 entradas por hoja**, sin entradas borradas.

### Parte D — El índice cubriente que sí pedirías

Q9 (los 20 pedidos más recientes con todas sus columnas) usa `IX_PED_FECHA`. Decide si añadirías columnas para hacerlo cubriente, mide la versión actual con `lab_tools.medir.consulta` y razona la decisión.

**Respuesta:** No añadiría todas las columnas para cubrir `SELECT *`: haría el índice muy ancho y encarecería cada `INSERT`. La versión actual devuelve **20 filas con 26 lecturas lógicas** usando `INDEX FULL SCAN DESCENDING IX_PED_FECHA` y acceso a la tabla (`20261103T013225Z_06-indices.script.log`, sección de medidas de Q9). Solo pediría un índice cubriente si el panel seleccionara pocas columnas estables.

### Parte E — Dibuja tu curva

Copia las columnas de la sección 3 de tu evidencia en una hoja de cálculo o con `awk` en la terminal y dibuja las tres curvas en escala logarítmica de `k`. Marca dónde se cruza cada índice con la línea de la tabla entera y dónde cambia el optimizador. Incluye la imagen en tus respuestas y explica en tres líneas por qué los tres puntos no coinciden.

**Respuesta:** La tabla completa permanece en **5232 lecturas**; el índice con CF bueno cruza esa línea cerca del 100 %, mientras el índice con CF malo la cruza entre **0.1 % y 0.2 %**. El punto teórico (`0.53 %` en lecturas lógicas) no coincide exactamente porque intervienen hojas del índice, *batching*, caché y el coste de lecturas aleatorias. El optimizador usa además estimaciones y costes internos (`20261103T011658Z_04-agrupamiento-equilibrio.script.log`, sección 3).

### Parte F — Revisión de código como en un equipo real

Un compañero abre un *Pull Request* con esta consulta para el panel de atención al cliente:

```sql
SELECT *
FROM tiendasur.cliente
WHERE SUBSTR(telefono, 1, 3) = '600'
   OR UPPER(apellidos) = 'GIL';
```

Escribe el comentario de revisión: qué reglas rompe, la reescritura propuesta y las lecturas medidas antes y después con `lab_tools.medir.consulta`. Los índices temporales de esta parte se borran al final del script: créalos de nuevo para la prueba y bórralos después.

**Respuesta — comentario de revisión:** La consulta aplica `SUBSTR` y `UPPER` sobre columnas y usa `OR`; rompe la sargabilidad. Si la intención era una coincidencia conjunta, propondría `WHERE telefono LIKE '600%' AND apellidos = 'GIL'`; si era `OR`, mantendría índices en ambas ramas y usaría `UNION` con deduplicación. En la prueba equivalente, el `OR` sin índice de teléfono hizo **1486 lecturas**, y con ambos índices bajó a **6**; la versión con `UNION` también hizo **6** (`20261103T012326Z_05-sargabilidad.script.log`, líneas 42-52).

### Parte G — Defiende tu propio índice

Elige una consulta de la Actividad 3.2 que `V005` no cubra y propón un índice. Escríbelo como `V006` en una rama aparte, pásalo por las cinco preguntas con números del banco (lecturas antes y después, bloques por fila de `INSERT` con `06-medir-dml.sql` y redundancia) y redacta la descripción del *Pull Request*. Si no compensa, documéntalo y no lo fusiones.

**Respuesta:** Elegí Q7, el historial por cliente, y propuse `IX_PED_CLI_FEC (id_cliente, fecha_pedido DESC)`. La consulta pasó de **15** a **7** lecturas; la versión cubriente baja a **3** (`20261103T011106Z_03-tipos-indice.script.log`, sección 3). `IX_PED_CLIENTE` queda cubierto por el prefijo del índice compuesto. El coste medido pasó de **10.1 bloques por INSERT** con 4 índices a **20.2** con 9, aproximadamente 2 por índice (`20261103T013225Z_06-indices.script.log`, líneas 7, 20 y 68-75). **PR:** “Añade índice compuesto para ordenar el historial por cliente sin SORT; incluye lecturas antes/después, coste DML y eliminación del índice simple redundante”.

### Parte H — Diagnostica sin ver el script

El profesor creará un índice degradado en un esquema de pruebas sin indicar cómo. Con `grafico-indice.sh` e `INDEX_STATS`, decide si está sano, fragmentado o en patrón cola; propón el remedio y justifícalo con dos cifras antes y después. Entrega el diagnóstico como comentario en tu *Issue*.

**Respuesta — diagnóstico:** Era patrón cola: `INDEX_STATS` mostró **70 619 entradas borradas**, el **41 %** de 170 619, y la búsqueda del mensaje más antiguo costó **226 lecturas** (`20261103T013805Z_07b-patron-cola.script.log`, líneas 1-16). Elegí `COALESCE`, que dejó **0 entradas borradas** y redujo la consulta a **2 lecturas**, en línea (`20261103T013805Z_07c-remedios.script.log`, líneas 1-15).

### Parte I — El MTTR bajo carga

Ejecuta el paso 1 de `13-lgwr-dbwn.sql` (un `UPDATE` de 20 000 filas) y, sin hacer *checkpoint*, consulta:

```sql
SELECT estimated_mttr, actual_redo_blks
FROM v$instance_recovery;
```

Anota cuánto crecen ambos valores y explica en una frase la relación entre redo pendiente y tiempo de recuperación.

**Respuesta:** El paso 1 registró **1779 KB de redo**, **3 escrituras LGWR** y **231 bloques sucios**; después del checkpoint DBWn escribió **347 bloques** y quedaron **0 bloques sucios** (`20261103T021318Z_13-lgwr-dbwn.script.log`, líneas 1-14). Cuanto más redo y bloques sucios quedan pendientes, mayor trabajo tiene que aplicar SMON y mayor es el MTTR.

### Parte K — Dimensiona el redo de TiendaSur

Con la sección 6 del runbook (Parte P), o con la siguiente consulta, cuenta los cambios de log de la hora en que cargaste TiendaSur:

```sql
SELECT TO_CHAR(first_time, 'HH24'), COUNT(*)
FROM v$log_history
GROUP BY TO_CHAR(first_time, 'HH24');
```

Propón un tamaño de grupo para que esa carga produjera como mucho cuatro cambios y escribe, sin ejecutarlos, los comandos para migrar a ese tamaño.

**Respuesta:** La evidencia muestra grupos de **200 MB** y cambios en las secuencias 23 a 27 (`20261103T015543Z_10-redo.script.log`, líneas 1-7 y 64-66). Para no superar cuatro cambios, propongo grupos de **512 MB**, sujeto a confirmar el redo exacto y el espacio disponible. Los comandos serían:

```sql
ALTER DATABASE ADD LOGFILE GROUP 4
  ('/opt/oracle/oradata/FREE/redo04.log',
   '/opt/oracle/oradata/FREE/redo04b.log') SIZE 512M;
```

Repetiría para los grupos nuevos, haría `SWITCH LOGFILE` y retiraría los antiguos solo cuando estuvieran `INACTIVE` y archivados.

### Parte M — El coste de un DELETE en tu FRA

Con la base en `ARCHIVELOG`, anota `SELECT space_used FROM v$recovery_file_dest;`, ejecuta el script `12-undoy-redo` una vez más y fuerza `ALTER SYSTEM ARCHIVE LOG CURRENT;`. Calcula cuánto creció la FRA, compáralo con la suma de la columna de redo de la tabla y explica la diferencia.

**Respuesta:** La FRA pasó de **6.6 MB** a **8.4 MB**, un crecimiento de **1.8 MB** (`20261103T020313Z_11-fra-llena.script.log`, líneas 1-4 y 39-46). No coincide con el redo de una columna porque la FRA almacena archivados completos, metadatos, undo, índices y cambios de bloques. En el escenario extremo, una FRA de **2 MB** llegó al 100 % y produjo `ORA-19815` y `ORA-19809` (`líneas 32-33`).

### Parte O — Escribe el runbook del simulacro D

Redacta en [`docs/runbooks/perdida-datafile.md`](../runbooks/perdida-datafile.md) el procedimiento para un compañero de guardia que no ha hecho este laboratorio: síntoma (los tres `ORA-` y, si aparece, `ORA-63999`), comprobaciones previas (`ARCHIVELOG`, copia disponible, `LIST BACKUP OF DATAFILE n;` y estado de la PDB), comandos para cada uno de los dos caminos, verificación (`V$PDBS` y la fila de control) y a quién avisar. Máximo una página.

**Respuesta:** El procedimiento aplicado fue identificar el datafile 16 por `ORA-01116`, `ORA-01110` y `ORA-27041`, comprobar `ARCHIVELOG`, la copia RMAN y que `FREEPDB1` estaba `MOUNTED`, ejecutar `RESTORE DATAFILE 16`, `RECOVER DATAFILE 16`, devolverlo a `ONLINE` y abrir la PDB. Si aparece `ORA-63999`, se repara con la PDB montada y se abre después. La PDB quedó `READ WRITE`, la fila 104 sobrevivió, el RPO fue **0** y el RTO **8 s** desde offline a online (**9 s** desde el fallo) (`20261103T022359Z_14d-perdida-datafile.script.log`, líneas 25-60).

### Parte P — Un umbral que dispare una alerta

Elige una de las nueve secciones y escribe la consulta que devolvería una sola fila solo cuando haya que despertar a alguien, por ejemplo, cuando la FRA supere el 85 % o no exista ninguna copia RMAN en 24 horas. Explica cómo se conectaría esta comprobación con un sistema de alertas.

**Respuesta:** Elegí la FRA:

```sql
SELECT name, space_used, space_limit,
       ROUND(space_used * 100 / space_limit, 2) pct_used
FROM v$recovery_file_dest
WHERE space_used * 100 / space_limit > 85;
```

En el simulacro, `ORA-19815` registró **100 %** de uso y **0 remaining**, seguido de `ORA-19809` (`20261103T020313Z_11-fra-llena.script.log`, líneas 32-33). Un job ejecutaría esta consulta periódicamente y enviaría la fila a la herramienta de alertas; si no devuelve filas, no despierta a nadie.

## 8. Preguntas de comprobación

Respóndelas en `docs/bitacora/lab5-respuestas.md` con tus propias palabras y citando tu evidencia (nombre del archivo y la línea o el valor que lo demuestra). Una respuesta sin cifra propia no puntúa.

### 8.1. Punto de partida y banco de medida (A, B)

1. Compara el paso 6 de tu copia `lab4-final` con el de la copia `lab3-final`. ¿Qué demuestra la diferencia?

**Respuesta:** `lab3-final` era una copia en frío consistente; `lab4-final` conserva además los cambios y objetos creados en Lab 4. La evidencia de la copia confirma `tipo=copia en frio consistente` y `archivos_fuera_del_volumen=0` (`docs/bitacora/lab4-respuestas.md`, líneas 7-8); la verificación de Lab 5 confirma que el backup de Lab 4 está íntegro (`docs/bitacora/lab5/evidencia/script/20261103T034101Z_16-verificacion-final.script.log`, línea 2). La diferencia demuestra que el backup posterior parte de un estado más avanzado y validado.

2. Calcula el factor de bloqueo (BFR) de `CLIENTE` y de `PEDIDO` con sus estadísticas. ¿Por qué `PEDIDO` cabe casi el triple de filas por bloque?

**Respuesta:** `CLIENTE`: `100000 / 1517 = 65.9`, aproximadamente **66 filas por bloque**. `PEDIDO`: `1000000 / 5320 = 188.0`, aproximadamente **188 filas por bloque**. `PEDIDO` tiene filas de 32 bytes frente a 102 bytes en `CLIENTE`, por eso caben casi `188 / 66 = 2.85` veces más (`20261103T002048Z_01-perfil-tiendasur.script.log`, líneas 1-7).

3. ¿Por qué el banco de medida ejecuta cada sentencia dos veces y mide solo la segunda?

**Respuesta:** La primera ejecución puede incluir trabajo de calentamiento o limpieza de bloques; la segunda mide el coste estable en caliente. En la evidencia, ambas devuelven una fila, pero la segunda registra **4 buffers lógicos** en la búsqueda por `PK_PEDIDO` (`20261103T010315Z_02-anatomia-indice.script.log`, sección 3).

### 8.1.1. Anatomía y tipos de índice (C, D)

4. Con tu evidencia 02: altura, número de hojas y factor de ramificación (*fan-out*) real de `IX_PED_CLIENTE`. ¿Qué altura tendría con mil millones de filas?

**Respuesta:** `IX_PED_CLIENTE` tiene altura **3**, **2216 hojas** y fan-out real **370**, calculado como `(2216 + 6 - 1) / 6` (`20261103T010315Z_02-anatomia-indice.script.log`, líneas 19-23). Con mil millones de filas tendría **2 208 969 hojas**, altura **4** y unas **5 lecturas lógicas** para encontrar una fila incluyendo la tabla (`líneas 25-27`).

5. En el volcado de la hoja de `PK_CLIENTE`, localiza una entrada y descompón el `ROWID` que guarda en bloque y fila. ¿Por qué no aparece el número de archivo?

**Respuesta:** La entrada de `ID_CLIENTE = 1` guarda bloque **795** (`0x0000031B`) y ranura **0**; los 6 bytes son **4 bytes de bloque + 2 de ranura** (`20261103T010315Z_02-anatomia-indice.script.log`, líneas 142-147). No aparece el archivo porque es un ROWID corto de un tablespace *bigfile*: el datafile se identifica implícitamente por el tablespace.

6. Elige tres pruebas de la Parte D y explica, con las lecturas lógicas medidas, por qué un tipo de índice gana al otro.

**Respuesta:** (1) `Q6` solo por ciudad usa *skip scan* con **144** lecturas, frente a **103** filtrando país y ciudad con *range scan*; (2) `Q7` baja de **15** a **7** y luego a **3** lecturas al pasar de índice simple a compuesto y cubriente; (3) `Q14` baja de **4073** a **528** lecturas con bitmaps. Son mejores porque respetan el prefijo, evitan ordenación/acceso a tabla o combinan filtros de baja cardinalidad (`20261103T011106Z_03-tipos-indice.script.log`, líneas 15-24, 27-35 y 56-67).

### 8.1.2. Agrupamiento, equilibrio y sargabilidad (E, F)

7. ¿Por qué `IX_PED_FECHA` tiene un *clustering factor* cercano al número de bloques e `IX_PED_CLIENTE` cercano al de filas? ¿Lo arreglaría un `REBUILD`?

**Respuesta:** `IX_PED_FECHA` tiene `CF = 5220`, casi los **5320 bloques** de `PEDIDO`, porque las fechas siguen el orden físico. `IX_PED_CLIENTE` tiene `CF = 999041`, casi el **1 000 000 de filas**, porque los clientes saltan entre bloques. Un `REBUILD` no lo arregla: el CF depende del orden físico de la tabla, no del orden interno del índice (`20261103T011658Z_04-agrupamiento-equilibrio.script.log`, líneas 1-18).

8. Según tu curva de la Parte E, ¿a partir de qué porcentaje deja de compensar cada índice? Compáralo con la fórmula de la Unidad 3.

**Respuesta:** El índice de CF malo deja de ganar aproximadamente entre **0.1 % y 0.2 %**: a `0.1 %` lee **975** bloques y a `0.2 %` **2004**, aunque la tabla lee **5232**; el optimizador ya elige tabla en `0.2 %`. El índice bueno sigue ganando hasta cerca del **100 %**, donde lee **7875** frente a **5232**. La fórmula da `1 / BFR = 1/188 = 0.53 %` en lecturas lógicas, y aproximadamente **0.11 %** ponderando lecturas aleatorias (`20261103T011658Z_04-agrupamiento-equilibrio.script.log`, sección 3).

9. Explica por qué Q4b (`'Gonz%'`) usa el índice y aun así lee más bloques que un recorrido completo.

**Respuesta:** `'Gonz%'` es un rango sargable desde el principio de la cadena, por eso usa `IX_CLI_APELLIDOS`; devuelve **2056 filas** y hace **2024 lecturas lógicas**, más que las **1517** páginas de un recorrido completo de `CLIENTE`. El índice añade lecturas de hojas y de bloques de tabla, aunque evita revisar filas que no empiezan por `Gonz` (`20261103T012326Z_05-sargabilidad.script.log`, líneas 36-40).

### 8.1.3. Coste de escritura y mantenimiento (G, H)

10. Con tu evidencia 06: bloques modificados por `INSERT` con 4, 9 y 5 índices. ¿Qué índices de la propuesta del compañero rechazaste y con qué dato?

**Respuesta:** Con 4 índices se modificaron **20 174 bloques** (**10.1 por fila**); con 9, **40 341** (**20.2 por fila**); con V005 y 5 índices, **24 452** (**12.2 por fila**). Rechacé los índices no usados o no viables, especialmente `IX_PED_CANAL` y `IX_PED_ESTADO` por su cardinalidad (33.3 % y 25 % por valor), además de los redundantes `IX_PED_CLIENTE` e `IX_PED_FECHA`. Cada índice adicional añade aproximadamente **2 bloques modificados por INSERT** (`20261103T013225Z_06-indices.script.log`, líneas 7, 20, 60-75 y 140).

11. Distingue, con tus gráficos de la Parte H, un índice con divisiones 50/50, uno con divisiones 90/10 y uno con patrón cola.

**Respuesta:** `IX_AZAR` muestra el patrón aproximadamente **50/50**: **595** divisiones, ninguna 90/10 y **336 entradas por hoja**. `IX_CRECIENTE` muestra divisiones **90/10**: **398 de 398** splits fueron 90/10 y tiene **501 entradas por hoja**. `IX_COLA` es patrón cola porque conserva **70 619 entradas borradas**, el **41 %**, y la consulta del mensaje más antiguo lee **226** bloques (`20261103T013805Z_07a-crecimiento.script.log`, líneas 1-14; `07b-patron-cola.script.log`, líneas 1-16).

12. ¿Qué remedio elegirías para el patrón cola en producción, en horario de servicio, y por qué?

**Respuesta:** Elegiría `ALTER INDEX ... COALESCE`, porque es en línea y redujo las lecturas de **226 a 2**, eliminó las **70 619** entradas borradas y no requiere reconstruir el índice. `SHRINK SPACE` también bajó a 2 lecturas, pero lo reservaría si necesito devolver espacio al tablespace; a largo plazo particionaría por fecha (`20261103T013805Z_07c-remedios.script.log`, líneas 1-15).

### 8.1.4. SCN, control files, redo y FRA (I a L)

13. Con tu evidencia 08: ¿qué valores compara Oracle al abrir para decidir si hace falta recuperación?

**Respuesta:** Compara el **SCN de checkpoint del control file** con el **SCN de checkpoint de la cabecera de cada datafile**. En la evidencia ambos son `10895033` para `SYSTEM`, `SYSAUX` y `academia01`, por lo que aparecen como `sincronizado` (`20261103T014444Z_08-scn-checkpoint.script.log`, líneas 12-24).

14. ¿Qué protege la multiplexación del control file en el mismo volumen y qué no? ¿Cómo se haría en producción?

**Respuesta:** Tres copias en el mismo volumen protegen frente a la pérdida o corrupción de una copia individual; la evidencia muestra `control01.ctl`, `control02.ctl` y `control03.ctl`, cada una de **18 792 448 bytes** (`20261103T015011Z_09-multiplexar-controlfile.script.log`, líneas 11-13). No protege frente a la pérdida del volumen, filesystem o servidor completo. En producción las pondría en discos, cabinas o zonas de disponibilidad independientes.

15. Explica los estados `CURRENT`, `ACTIVE` e `INACTIVE` con tu evidencia 10 y por qué Oracle rechaza los tres borrados del paso 4.

**Respuesta:** `CURRENT` es el grupo que recibe redo; `ACTIVE` aún puede ser necesario para recuperación de instancia; `INACTIVE` ya no se necesita para esa recuperación. La evidencia muestra los grupos 1 `INACTIVE`, 2 `ACTIVE` y 3 `CURRENT` (`20261103T015543Z_10-redo.script.log`, líneas 35-43). Oracle rechaza borrar el `CURRENT` con `ORA-01623`, su miembro con `ORA-01609` y el grupo necesario para *crash recovery* con `ORA-01624` (`líneas 58-62`).

16. Describe la cadena de causas del escenario de la FRA llena, desde `ORA-19815` hasta que la base deja de aceptar cambios.

**Respuesta:** La FRA alcanza el **100 %** (`ORA-19815`, `0 remaining`) y Oracle emite `ORA-19809`; `ARCn` no puede archivar el grupo 2, por lo que `ALTER SYSTEM ARCHIVE LOG CURRENT` falla con `ORA-16038`. Al no poder liberar el redo, los grupos quedan activos y las sesiones terminan esperando `log file switch (archiving needed)`; finalmente nuevas conexiones pueden recibir `ORA-00257` (`20261103T020313Z_11-fra-llena.script.log`, líneas 10-18 y 26-33).

### 8.1.5. Undo, WAL y simulacros (M a P)

17. Explica, con los pasos 1 a 4 de tu evidencia 12, la frase «lectores no bloquean a escritores».

**Respuesta:** La sesión A actualiza la fila 101 sin confirmar y consume **1 bloque** y **1 registro de undo**; B puede leer el valor confirmado `ACTIVO` sin esperar. En cambio, cuando B intenta `FOR UPDATE`, sí espera y recibe `ORA-00054` porque solicita el bloqueo de la misma fila. Tras el `COMMIT` de A, B ve `EGRESADO` (`20261103T020908Z_12-lectura-consistente.script.log`, líneas 1-24 y 54-66). Por tanto, las lecturas normales usan undo, pero los escritores necesitan el bloqueo.

18. ¿Por qué un `DELETE` genera más undo que un `INSERT`? ¿Por qué el `ROLLBACK` también genera redo?

**Respuesta:** En 10 000 filas, `INSERT` usó **141 bloques de undo** y **2034 KB** de redo descriptivo del undo; `DELETE` usó **427 bloques** y **3262 KB**, porque debe guardar la fila completa y sus entradas de índice. El `ROLLBACK` también generó redo porque deshacer es otra modificación protegida: **356 KB** para INSERT frente a **4701 KB** para DELETE (`20261103T021116Z_12-undo-y-redo.script.log`, líneas 1-10).

19. Con tu evidencia 13: ¿dónde está la garantía de durabilidad justo después del `COMMIT`? ¿Y después del *checkpoint*?

**Respuesta:** Justo después del `COMMIT`, la garantía está en que LGWR escribió el redo: el paso 1 registra **1779 KB de redo**, **3 escrituras LGWR** y **1 commit**, mientras quedan **231 bloques sucios**. Después del checkpoint, DBWn escribe esos bloques: el paso 2 registra **347 bloques DBWn** y **0 bloques sucios**, sin necesidad de otro commit (`20261103T021318Z_13-lgwr-dbwn.script.log`, líneas 1-14).

20. Simulacro A: explica *roll forward* y *roll back* con las filas 102 y 103 y las líneas del *alert log*.

**Respuesta:** Antes de la caída, la fila 102 estaba `EGRESADO` y confirmada; la 103 estaba `INACTIVO` y sin confirmar. Tras `SHUTDOWN ABORT`, SMON hace *roll forward* aplicando el redo: leyó **32 KB** y recuperó **47 bloques**; después hace *roll back* de la transacción no confirmada. El resultado fue 102 `EGRESADO` y 103 `ACTIVO`, confirmado por el log de recuperación (`20261103T021629Z_14a-caida-instancia.script.log`, líneas 1-6, 19-32).

21. Simulacros C y D: tu RTO y tu RPO en cada uno. ¿Por qué son tan distintos?

**Respuesta:** En el simulacro C, la restauración completa tardó **77 s** y el RPO fue todo lo hecho durante los **1 s** entre la copia y el fallo (`20261103T033304Z_14c-simulacro-restauracion.script.log`, líneas 52-54). En el simulacro D, recuperar el datafile tardó **8 s** desde offline a online, **9 s** desde el fallo, y el RPO fue **0** porque se aplicaron la copia, redo archivado y redo online (`20261103T022359Z_14d-perdida-datafile.script.log`, líneas 51-60). Son distintos porque C restaura el estado completo desde una copia, mientras D recupera solo el datafile con redo y mantiene el resto de la base disponible.

22. Clasifica cada error `ORA-` del bloque 5 de tu runbook: incidente real, efecto del laboratorio o ruido conocido.

**Respuesta:** `ORA-19815`, `ORA-19809`, `ORA-16038` y `ORA-00312` son el efecto controlado del laboratorio de FRA llena (`20261103T020313Z_11-fra-llena.script.log`, líneas 10-18 y 32-33). `ORA-00205` y `ORA-27037` son el efecto controlado de borrar una ruta de control file (`20261103T021702Z_14b-perdida-controlfile.script.log`, líneas 6-27). `ORA-01113`, `ORA-01110` y `ORA-63999` representan el incidente de pérdida de datafile simulado (`20261103T034033Z_15-healthcheck.spool.log`, líneas 34-38); `ORA-00800` queda como ruido conocido del entorno (`líneas 40-42`).

## Preguntas tipo examen

### B1

Un plan real muestra `E-Rows = 25 000` y `A-Rows = 20` en el paso de acceso por índice sobre la columna `estado`. ¿Cuál es la causa más probable?

**Respuesta: B.** El histograma corrige la estimación cuando la distribución está sesgada.

- A. El índice está fragmentado.
- B. Faltan estadísticas con histograma en una columna de distribución sesgada.
- C. La tabla tiene filas migradas.
- D. La consulta no es sargable.

### C1

Un índice tiene `BLEVEL = 2` en `DBA_INDEXES`. ¿Cuántas lecturas lógicas necesita, como mínimo, una búsqueda por igualdad sobre su clave única que devuelve una columna que no está en el índice?

**Respuesta: C.** Se leen raíz, rama, hoja y el bloque de tabla para obtener la columna no cubierta.

- A. 2
- B. 3
- C. 4
- D. 5

### C2

Un índice tiene 2 000 000 de hojas y un factor de ramificación máximo de 500. ¿Qué altura tendrá?

**Respuesta: C.** Con factor 500, dos millones de hojas requieren cuatro niveles de árbol.

- A. 2
- B. 3
- C. 4
- D. 5

### D1

Una tabla de hechos se carga una vez por noche y los analistas filtran por combinaciones de región (6 valores), canal (3) y año (5). ¿Qué tipo de índice es más apropiado en esas columnas?

**Respuesta: B.** Bitmap es adecuado para baja cardinalidad y cargas por lotes analíticas.

- A. B-tree compuesto (`region`, `canal`, `anio`).
- B. Un índice bitmap en cada columna.
- C. Un índice basado en funciones.
- D. Un clúster hash por `region`.

### D2

¿Qué dos afirmaciones sobre un índice cubriente son correctas? *(Elige dos.)*

**Respuesta: A y C.** Evita el acceso a la tabla, pero añade mantenimiento a las escrituras.

- A. Evita el acceso a la tabla si la consulta solo usa columnas del índice.
- B. Siempre ocupa menos que la tabla.
- C. Encarece cada `INSERT` y cada `UPDATE` de sus columnas.
- D. Se declara en Oracle con la cláusula `INCLUDE`.
- E. Solo puede tener una columna.

### E1

Un índice tiene `CLUSTERING_FACTOR = 9 950 000` sobre una tabla de 10 000 000 filas y 80 000 bloques. Una consulta pide el 3 % de las filas por ese índice. ¿Qué plan es razonable?

**Respuesta: B.** Un factor de agrupamiento casi igual al número de filas hace caro el acceso por índice.

- A. Rango por índice, porque el 3 % es poco.
- B. Recorrido completo de tabla.
- C. Reconstruir el índice para mejorar el CF y luego usar el índice.
- D. Un índice bitmap.

### F1

La columna `num_factura` es `VARCHAR2(10)` y tiene un índice. ¿Qué predicado impide usarlo?

**Respuesta: B.** La conversión implícita de la columna puede impedir usar el índice normal.

- A. `num_factura = '2025001'`
- B. `num_factura = 2025001`
- C. `num_factura LIKE '2025%'`
- D. `num_factura BETWEEN '2025000' AND '2025999'`

### F2

¿Qué dos reescrituras convierten `WHERE TRUNC(fecha) = DATE '2026-10-18'` en una condición sargable equivalente? *(Elige dos.)*

**Respuesta: A y C.** Ambas expresan el día como un rango sobre la columna sin aplicarle una función.

- A. `fecha >= DATE '2026-10-18' AND fecha < DATE '2026-10-19'`
- B. `fecha = DATE '2026-10-18'`
- C. `fecha BETWEEN DATE '2026-10-18' AND DATE '2026-10-18' + INTERVAL '86399' SECOND`
- D. `TO_CHAR(fecha, 'YYYY-MM-DD') = '2026-10-18'`
- E. `fecha + 0 = DATE '2026-10-18'`

### G1

Quieres comprobar si la aplicación sigue necesitando un índice antes de borrarlo, sin dejar de mantenerlo y pudiendo dar marcha atrás al instante. ¿Qué haces?

**Respuesta: B.** El índice invisible no se considera, pero continúa manteniéndose.

- A. `ALTER INDEX ... UNUSABLE`
- B. `ALTER INDEX ... INVISIBLE`
- C. `DROP INDEX` y recrearlo si hay quejas.
- D. `ALTER INDEX ... NOLOGGING`

### G2

Una tabla tiene 3 índices B-tree y recibe 500 `INSERT` de una fila por segundo. Con lo medido en esta parte, ¿cuántos bloques modificados por segundo, aproximadamente, añade un cuarto índice?

**Respuesta: C.** El cuarto índice añade aproximadamente cuatro bloques modificados por cada inserción.

- A. Unos 500
- B. Unos 1000
- C. Unos 2000
- D. Ninguno: los índices se actualizan al hacer `COMMIT`.

### H1

Una tabla de eventos recibe claves crecientes y cada noche se borran los eventos de más de 30 días. La consulta «evento más antiguo pendiente» se ha vuelto lenta. ¿Qué acción resuelve el síntoma en línea y con el menor coste?

**Respuesta: B.** `COALESCE` compacta hojas en línea con menor coste que una reconstrucción completa.

- A. `ALTER INDEX ... REBUILD`
- B. `ALTER INDEX ... COALESCE`
- C. Crear el índice como `REVERSE`.
- D. `DBMS_STATS.GATHER_INDEX_STATS`

### H2

¿Qué dos afirmaciones sobre un índice `REVERSE` son correctas? *(Elige dos.)*

**Respuesta: A y C.** Distribuye inserciones secuenciales y no permite búsquedas eficientes por rango.

- A. Reduce la contención en la hoja de más a la derecha con claves crecientes.
- B. Permite rangos más rápidos que un índice normal.
- C. No puede usarse para una condición `BETWEEN` sobre la clave.
- D. Mejora el factor de agrupamiento de la tabla.
- E. Evita las divisiones de hoja.

### I1

Al abrir la base, ¿qué compara Oracle para decidir si un datafile necesita recuperación?

**Respuesta: B.** Se comparan los SCN de checkpoint del control file y de la cabecera del datafile.

- A. El tamaño del datafile con el registrado en el diccionario.
- B. El SCN de checkpoint del control file con el de la cabecera del datafile.
- C. La fecha de modificación del archivo en el sistema operativo.
- D. El número de bloques sucios del buffer cache.

### J1

Una de las tres copias del control file se corrompe con la base abierta. ¿Qué ocurre?

**Respuesta: B.** La copia dañada debe sustituirse por una sana o retirarse de `CONTROL_FILES`.

- A. Oracle sigue funcionando con las dos copias restantes sin ningún aviso.
- B. La instancia se detiene; hay que sustituir la copia dañada por una sana (o quitarla de `CONTROL_FILES`) y arrancar.
- C. Oracle recrea automáticamente la copia dañada a partir de las otras.
- D. Hay que restaurar todos los datafiles desde la última copia.

### J2

¿Qué dos datos guarda el control file? *(Elige dos.)*

**Respuesta: A y C.** Registra los archivos de la base y el SCN del último checkpoint.

- A. El nombre y la ubicación de los datafiles y redo logs.
- B. Los valores de los parámetros de inicialización.
- C. El SCN del último checkpoint.
- D. Las contraseñas de los usuarios `SYSDBA`.
- E. Las filas del diccionario de datos.

### K1

Un grupo de redo tiene estado `ACTIVE`. ¿Qué afirmación es correcta?

**Respuesta: C.** `ACTIVE` indica que el redo aún puede ser necesario para la recuperación de instancia.

- A. `LGWR` está escribiendo en él.
- B. Se puede borrar sin consecuencias.
- C. Contiene cambios que aún podrían necesitarse para una recuperación de instancia.
- D. Ya ha sido archivado necesariamente.

### L1

Un DBA ejecuta `ALTER SYSTEM SET db_recovery_file_dest = '/u03/fra';` en una base sin FRA configurada y recibe un error. ¿Cuál es la causa?

**Respuesta: B.** Primero debe establecerse `DB_RECOVERY_FILE_DEST_SIZE`.

- A. La base no está en `ARCHIVELOG`.
- B. Falta fijar antes `DB_RECOVERY_FILE_DEST_SIZE`.
- C. `DB_RECOVERY_FILE_DEST` es estático y exige `SCOPE=SPFILE`.
- D. La ruta debe ser un grupo ASM.

### L2

Las sesiones de una base en `ARCHIVELOG` se quedan esperando en `log file switch (archiving needed)` y las nuevas conexiones reciben `ORA-00257`. ¿Qué dos acciones resuelven el problema? *(Elige dos.)*

**Respuesta: A y C.** Se puede ampliar la FRA si hay espacio o respaldar y borrar archivados con RMAN.

- A. Aumentar `DB_RECOVERY_FILE_DEST_SIZE` si hay espacio en disco.
- B. Ejecutar `ALTER SYSTEM SWITCH LOGFILE` repetidamente.
- C. Hacer copia de los archivados con RMAN y borrarlos con `DELETE INPUT`.
- D. Pasar la base a `NOARCHIVELOG` en caliente.
- E. Borrar los `.arc` de la FRA con `rm`.

### M1

La sesión A ejecuta un `UPDATE` de una fila y no confirma. La sesión B consulta esa fila. ¿Qué ve B?

**Respuesta: C.** La lectura consistente reconstruye con undo el último valor confirmado.

- A. El valor nuevo, porque el bloque del buffer cache ya está modificado.
- B. Un error `ORA-00054`, porque la fila está bloqueada.
- C. El valor confirmado anterior, reconstruido con el undo.
- D. Nada: la consulta espera hasta que A haga `COMMIT` o `ROLLBACK`.

### M2

¿Qué operación de 10 000 filas genera, en general, **más undo**?

**Respuesta: C.** `DELETE` necesita undo para restaurar las filas eliminadas.

- A. `INSERT`
- B. `UPDATE` de una columna no indexada
- C. `DELETE`
- D. `SELECT ... FOR UPDATE`

### M3

Un informe nocturno falla con `ORA-01555`. ¿Qué dos medidas son adecuadas? *(Elige dos.)*

**Respuesta: B y D.** Más undo y `RETENTION GUARANTEE` reducen la sobrescritura de versiones necesarias.

- A. Aumentar el tamaño de los redo logs.
- B. Aumentar `UNDO_RETENTION` y el tamaño del tablespace de undo.
- C. Pasar la base a `NOARCHIVELOG`.
- D. Usar `RETENTION GUARANTEE` en el tablespace de undo si la consulta es crítica.
- E. Aumentar `LOG_BUFFER`.

### N1

Una sesión recibe «Commit complete». ¿Qué está garantizado en ese momento?

**Respuesta: A.** `COMMIT` garantiza que el redo llegó al redo log online.

- A. El redo de la transacción está escrito en el redo log online.
- B. Los bloques modificados están escritos en los datafiles.
- C. El redo de la transacción está archivado en la FRA.
- D. Se ha hecho un checkpoint.

### N2

¿En qué dos situaciones escribe `DBWn` bloques sucios en los datafiles? *(Elige dos.)*

**Respuesta: B y C.** `DBWn` escribe durante checkpoints y cuando necesita liberar buffers.

- A. En cada `COMMIT`.
- B. En un checkpoint.
- C. Cuando un proceso servidor no encuentra buffers libres.
- D. Cada 3 segundos, siempre.
- E. Cuando `LGWR` termina de escribir el log buffer.

### O1

Tras un corte de luz, el DBA ejecuta `STARTUP`. ¿Qué ocurre?

**Respuesta: B.** SMON aplica redo y deshace transacciones incompletas durante la recuperación de instancia.

- A. La base queda en `MOUNT` y hay que ejecutar `RECOVER DATABASE` manualmente.
- B. `SMON` aplica el redo online y deshace las transacciones no confirmadas; la base abre sin intervención.
- C. Hay que restaurar los datafiles desde la última copia porque son inconsistentes.
- D. Se pierden las transacciones confirmadas desde el último checkpoint.

### O2

Una base tiene tres copias del control file. Una se borra con la base cerrada y `STARTUP` da `ORA-00205`. ¿Qué dos acciones permiten abrir la base sin perder datos? *(Elige dos.)*

**Respuesta: B y D.** Se puede copiar una réplica sana o quitar la ruta perdida de `CONTROL_FILES`.

- A. `RECOVER DATABASE USING BACKUP CONTROLFILE`
- B. Copiar una de las copias sanas sobre la perdida y montar.
- C. `ALTER DATABASE OPEN RESETLOGS`
- D. Quitar la copia perdida de `CONTROL_FILES` en el SPFILE, reiniciar y montar.
- E. Restaurar todos los datafiles desde la última copia de RMAN.

### O3

En una base en `ARCHIVELOG` se pierde el datafile de un tablespace de aplicación. ¿Cuál es la secuencia que lo recupera sin cerrar la base y sin perder datos?

**Respuesta: B.** Se pone offline el datafile, se restaura, se recupera con redo y se vuelve online.

- A. `SHUTDOWN ABORT; STARTUP MOUNT; RESTORE DATABASE; RECOVER DATABASE; ALTER DATABASE OPEN RESETLOGS;`
- B. `ALTER DATABASE DATAFILE n OFFLINE; RESTORE DATAFILE n; RECOVER DATAFILE n; ALTER DATABASE DATAFILE n ONLINE;`
- C. `RESTORE DATAFILE n; ALTER DATABASE DATAFILE n ONLINE;`
- D. `FLASHBACK DATABASE TO SCN` anterior a la pérdida.

### O4

Un usuario ejecutó `DROP TABLE ventas PURGE` hace 10 minutos. La base está en `ARCHIVELOG` y hay copias de RMAN. ¿Qué opción recupera la tabla sin perder los cambios hechos en otras tablas?

**Respuesta: D.** `RMAN RECOVER TABLE` recupera la tabla sin restaurar los cambios de otras tablas.

- A. `FLASHBACK TABLE ventas TO BEFORE DROP;`
- B. Restaurar la última copia completa de la base.
- C. `SELECT * FROM ventas AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '15' MINUTE)`
- D. RMAN `RECOVER TABLE` hasta un instante anterior al `DROP`.

### S1

Un índice tiene un *clustering factor* muy cercano al número de filas de la tabla. ¿Qué afirmación es correcta?

**Respuesta: B.** Un factor alto implica que un rango visita casi un bloque distinto por cada fila.

- A. Las filas con claves consecutivas están en bloques contiguos de la tabla.
- B. Un recorrido por rango del índice visitará casi un bloque distinto de la tabla por cada fila.
- C. Reconstruir el índice reducirá el *clustering factor*.
- D. El índice está fragmentado y debe hacerse `COALESCE`.

### S2

La consulta `SELECT * FROM cliente WHERE UPPER(email) = :e` hace un recorrido completo aunque existe un índice sobre `EMAIL`. ¿Qué dos cambios permiten usar un índice? *(Elige dos.)*

**Respuesta: A y C.** Se puede indexar `UPPER(email)` o comparar el valor almacenado en minúsculas.

- A. Crear un índice basado en función sobre `UPPER(email)`.
- B. Reconstruir el índice sobre `EMAIL`.
- C. Si el email se guarda en minúsculas, escribir `WHERE email = LOWER(:e)`.
- D. Recoger estadísticas de la tabla.
- E. Añadir el hint `FULL`.

### S3

`CODIGO_POSTAL` es `VARCHAR2` y tiene índice. La consulta `WHERE codigo_postal = 30001` no lo usa. ¿Por qué?

**Respuesta: B.** La conversión implícita aplica `TO_NUMBER` a la columna y no coincide con el índice.

- A. Los índices no admiten columnas `VARCHAR2`.
- B. Oracle convierte la columna con `TO_NUMBER`, y el índice está sobre la columna sin convertir.
- C. El literal 30001 es demasiado selectivo.
- D. Falta un histograma sobre `CODIGO_POSTAL`.

### S4

¿En qué situación es más apropiado un índice bitmap?

**Respuesta: B.** Bitmap es apropiado para baja cardinalidad, análisis y poca concurrencia de escritura.

- A. Una columna con millones de valores distintos en un sistema transaccional.
- B. Una columna de estado con 4 valores en un almacén de datos que se carga por la noche y se consulta de día.
- C. Una clave primaria con muchas inserciones concurrentes.
- D. Una columna que se actualiza en cada transacción.

### S5

Existe un índice compuesto (`pais`, `ciudad`). `PAIS` tiene 5 valores distintos. Una consulta filtra solo por `CIUDAD`. ¿Qué operación puede elegir el optimizador?

**Respuesta: B.** `INDEX SKIP SCAN` puede omitir la primera columna de baja cardinalidad.

- A. `INDEX UNIQUE SCAN`
- B. `INDEX SKIP SCAN`
- C. `INDEX RANGE SCAN` sobre la columna `PAIS`
- D. `BITMAP CONVERSION`

### S6

Quieres comprobar si la aplicación necesita un índice antes de borrarlo, con marcha atrás inmediata. ¿Qué haces?

**Respuesta: B.** Un índice invisible permite probar el plan alternativo y revertirlo inmediatamente.

- A. `ALTER INDEX ... UNUSABLE`
- B. `ALTER INDEX ... INVISIBLE` y vigilar el rendimiento.
- C. `DROP INDEX` y recrearlo si hay quejas.
- D. `ALTER INDEX ... COALESCE`

### S7

Una tabla de mensajes inserta por un extremo y borra por el otro. El índice de la clave crece aunque el número de filas es estable. ¿Qué dos acciones lo resuelven sin bloquear la tabla? *(Elige dos.)*

**Respuesta: A y C.** `COALESCE` y `SHRINK SPACE` recuperan espacio en línea.

- A. `ALTER INDEX ... COALESCE`
- B. `ALTER INDEX ... REBUILD` (sin `ONLINE`)
- C. `ALTER INDEX ... SHRINK SPACE`
- D. Recoger estadísticas del índice.
- E. `ALTER TABLE ... MOVE`

### S8

¿Qué efecto tiene un índice de clave invertida (`REVERSE`) sobre una clave secuencial?

**Respuesta: B.** Invierte los bytes de la clave, reparte inserciones y deja de servir para rangos.

- A. Acelera las consultas por rango de la clave.
- B. Reparte las inserciones entre muchas hojas, pero impide usar el índice para rangos.
- C. Reduce el tamaño del índice a la mitad.
- D. Convierte el índice en un IOT.

### S9

Una tabla tiene 9 índices. ¿Qué operación **no** se encarece por el número de índices?

**Respuesta: C.** Si la columna no pertenece a ningún índice, ese `UPDATE` no mantiene índices.

- A. `INSERT`
- B. `DELETE`
- C. `UPDATE` de una columna que no está en ningún índice
- D. `MERGE` que inserta filas nuevas

### S10

¿Qué determina principalmente la altura de un índice B-tree con un número de filas dado?

**Respuesta: B.** Depende principalmente de las entradas que caben en cada bloque de rama.

- A. El *clustering factor*.
- B. El factor de ramificación (entradas por bloque de rama), que depende del tamaño de la clave.
- C. El número de columnas de la tabla.
- D. El valor de `PCTFREE` de la tabla.

### S11

¿Qué dos afirmaciones sobre una tabla organizada como índice (IOT) son correctas? *(Elige dos.)*

**Respuesta: A y C.** Las filas están en el índice de la clave primaria y no hay un segmento de tabla separado.

- A. Las filas se guardan en el propio índice de la clave primaria.
- B. No puede tener índices secundarios.
- C. Una búsqueda por clave primaria evita el acceso a un segmento de tabla aparte.
- D. No necesita clave primaria.
- E. Sus filas tienen `ROWID` físico fijo.

### S12

Al abrir la base, ¿qué compara Oracle para decidir si un datafile necesita recuperación?

**Respuesta: B.** Se comparan los SCN de checkpoint del control file y de la cabecera del datafile.

- A. El tamaño del datafile con el del diccionario.
- B. El SCN de checkpoint del control file con el de la cabecera del datafile.
- C. La fecha de modificación del archivo.
- D. El número de bloques sucios del buffer cache.

### S13

¿Qué proceso registra el checkpoint en el control file y en las cabeceras de los datafiles?

**Respuesta: C.** `CKPT` registra el checkpoint en el control file y en las cabeceras.

- A. `DBWn`
- B. `LGWR`
- C. `CKPT`
- D. `SMON`

### S14

La instancia está en estado `NOMOUNT`. ¿Qué dos consultas responden sin error? *(Elige dos.)*

**Respuesta: B y E.** En `NOMOUNT` están disponibles la instancia y los parámetros.

- A. `SELECT name FROM v$database;`
- B. `SELECT status FROM v$instance;`
- C. `SELECT username FROM dba_users;`
- D. `SELECT member FROM v$logfile;`
- E. `SELECT name, value FROM v$parameter;`

### S15

¿Cuál es la secuencia correcta para activar el modo `ARCHIVELOG`?

**Respuesta: B.** Se activa con la base montada, después de un apagado limpio.

- A. `ALTER DATABASE ARCHIVELOG` con la base abierta.
- B. `SHUTDOWN IMMEDIATE; STARTUP MOUNT; ALTER DATABASE ARCHIVELOG; ALTER DATABASE OPEN;`
- C. `STARTUP NOMOUNT; ALTER DATABASE ARCHIVELOG; ALTER DATABASE MOUNT;`
- D. `ALTER SYSTEM SET log_archive_start = TRUE SCOPE = BOTH;`

### S16

Se pierde el único miembro de un grupo de redo `INACTIVE` ya archivado. ¿Qué se hace?

**Respuesta: B.** Un redo `INACTIVE` ya archivado puede limpiarse y recrearse con `CLEAR LOGFILE`.

- A. Restaurar la base entera.
- B. `ALTER DATABASE CLEAR LOGFILE GROUP n` para recrearlo.
- C. `RECOVER DATABASE UNTIL CANCEL`
- D. Nada: Oracle lo recrea solo.

### S17

¿Qué dos usos tiene el undo además de permitir `ROLLBACK`? *(Elige dos.)*

**Respuesta: A y C.** Undo permite lectura consistente y consultas de Flashback.

- A. Lectura consistente.
- B. Recuperación de medios de un datafile.
- C. Consultas de flashback (`AS OF`).
- D. Archivado del redo.
- E. Ordenaciones grandes.

### S18

¿Por qué un cambio en el undo también genera redo?

**Respuesta: B.** El redo debe poder rehacer los bloques de undo antes de deshacer cambios tras una caída.

- A. Porque el undo se guarda en el redo log.
- B. Porque los bloques de undo pueden perderse en una caída y hay que poder rehacerlos antes de deshacer.
- C. Porque `LGWR` escribe el undo en los datafiles.
- D. No lo genera: el undo es independiente del redo.

### S19

Una sesión recibe «Commit complete». ¿Qué está garantizado?

**Respuesta: A.** `COMMIT` garantiza que el redo está escrito en el redo log online.

- A. El redo de la transacción está en el redo log online.
- B. Los bloques modificados están en los datafiles.
- C. El redo está archivado en la FRA.
- D. Se ha hecho un checkpoint.

### S20

El parámetro `FAST_START_MTTR_TARGET` se reduce de 300 a 30. ¿Qué efecto tiene?

**Respuesta: A.** Un MTTR menor induce checkpoints más frecuentes y acelera la recuperación de instancia.

- A. Los checkpoints incrementales son más frecuentes y la recuperación de instancia más rápida.
- B. `LGWR` escribe con más frecuencia.
- C. Se archivan antes los redo logs.
- D. Aumenta la retención de undo.

### S21

Las sesiones esperan en `log file switch (archiving needed)`. ¿Cuál es la causa más probable?

**Respuesta: B.** `ARCn` no puede archivar, por ejemplo porque la FRA está llena.

- A. El redo log es demasiado grande.
- B. `ARCn` no puede archivar, por ejemplo porque la FRA está llena.
- C. Hay demasiados índices en la tabla.
- D. `UNDO_RETENTION` es demasiado bajo.

### S22

Una consulta falla con `ORA-01116`, `ORA-01110` y `ORA-27041` sobre el datafile de un tablespace de aplicación. La base está en `ARCHIVELOG` y hay copias de RMAN. ¿Qué es lo **PRIMERO** que haces para mantener el resto del servicio?

**Respuesta: B.** Aislar el datafile mantiene operativo el resto del servicio.

- A. `SHUTDOWN ABORT`
- B. `ALTER DATABASE DATAFILE n OFFLINE`
- C. `RESTORE DATABASE`
- D. `ALTER SYSTEM SWITCH LOGFILE`

### S23

Se pierde un datafile del tablespace `SYSTEM`. ¿Qué secuencia es correcta?

**Respuesta: B.** El datafile `SYSTEM` requiere montar la base para restaurarlo y recuperarlo.

- A. `OFFLINE`, `RESTORE`, `RECOVER`, `ONLINE` con la base abierta.
- B. `SHUTDOWN ABORT`, `STARTUP MOUNT`, `RESTORE DATAFILE`, `RECOVER DATAFILE`, `ALTER DATABASE OPEN`.
- C. `FLASHBACK TABLESPACE SYSTEM`
- D. `ALTER DATABASE OPEN RESETLOGS`

### S24

En `NOARCHIVELOG` se pierde un datafile de aplicación. ¿Qué afirmación es correcta?

**Respuesta: B.** En `NOARCHIVELOG` se depende de una copia en frío y se pierde lo posterior a ella.

- A. Se recupera con `RECOVER DATAFILE` sin pérdida.
- B. Solo se puede restaurar desde una copia en frío y se pierde lo posterior a ella.
- C. Se recupera con `FLASHBACK DATABASE`.
- D. `SMON` lo recupera al arrancar.

### S25

¿Qué dos medidas son adecuadas ante `ORA-01555` en un informe nocturno? *(Elige dos.)*

**Respuesta: B y D.** Hay que conservar más undo y, si es crítico, garantizar su retención.

- A. Aumentar el tamaño de los redo logs.
- B. Aumentar `UNDO_RETENTION` y el tamaño del undo.
- C. Pasar a `NOARCHIVELOG`.
- D. `RETENTION GUARANTEE` en el tablespace de undo si la consulta es crítica.
- E. Aumentar `LOG_BUFFER`.

### S26

¿Qué vista muestra el uso de la FRA por tipo de archivo?

**Respuesta: A.** `V$RECOVERY_AREA_USAGE` muestra el uso de la FRA por tipo de archivo.

- A. `V$RECOVERY_AREA_USAGE`
- B. `V$ARCHIVE_DEST`
- C. `DBA_FREE_SPACE`
- D. `V$LOG`
