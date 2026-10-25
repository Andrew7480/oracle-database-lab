# Lab 4 — Respuestas y análisis de evidencias

## 1. ¿Por qué la copia de la Parte B es consistente? ¿Qué pasaría si la base de datos estuviera abierta?

La copia es consistente porque se realiza con la base de datos detenida mediante `SHUTDOWN IMMEDIATE`, antes de empaquetar el volumen. Así se evita copiar archivos mientras Oracle los está modificando y se obtiene una copia en frío consistente.

El manifiesto confirma `tipo=copia en frio consistente (SHUTDOWN IMMEDIATE)` y `archivos_fuera_del_volumen=0`.

**Evidencias:**
- `backups/20261024T185003Z_lab3-final/manifiesto.txt`, líneas 7–8.
- `scripts/ops/backup-estado.sh`, líneas 41–50.

Si se copiara el volumen con la base de datos abierta, los archivos podrían cambiar durante la copia y quedar en estados correspondientes a momentos diferentes. La copia podría no ser recuperable o requerir recuperación adicional. Para obtener una copia consistente en caliente habría que utilizar un procedimiento de respaldo compatible con Oracle, no copiar sin más los archivos de una base abierta.

## 2. ¿Para qué sirven `manifiesto.txt` y `SHA256SUMS`? ¿Qué comprueba `restaurar-estado.sh` antes de restaurar?

`manifiesto.txt` documenta las características del respaldo: etiqueta, fecha UTC, contenedor, volumen, imagen, commit de Git y tipo de copia. Permite saber qué se guardó y en qué condiciones.

`SHA256SUMS` contiene los hashes SHA-256 de los archivos del respaldo. Sirve para comprobar que no se han alterado o corrompido desde que se calcularon los hashes; no demuestra por sí solo que una base de datos pueda arrancar correctamente.

**Evidencias:**
- `backups/20261024T185003Z_lab3-final/manifiesto.txt`, líneas 1–8.
- `backups/20261024T185003Z_lab3-final/SHA256SUMS`, entradas de los cuatro archivos.
- `scripts/ops/backup-estado.sh`, líneas 63–74.

En la salida obtenida, `nl -ba scripts/ops/restaurar-estado.sh` no mostró ninguna línea. Por tanto, **no puedo confirmar qué comprobaciones realiza actualmente ese script antes de restaurar**. Antes de usarlo, habría que verificar que valida el respaldo y sus hashes, comprueba las rutas y el volumen de destino y evita sobrescribir datos sin una confirmación adecuada.

## 3. Define RPO y RTO utilizando el respaldo del laboratorio.

- **RPO (Recovery Point Objective):** cantidad máxima de datos que se acepta perder, expresada como tiempo entre el último punto recuperable y el incidente.
- **RTO (Recovery Time Objective):** tiempo máximo objetivo para recuperar el servicio.

En este laboratorio, el manifiesto identifica una copia en frío etiquetada `lab3-final`, generada el `2026-10-24` a las `18:51:40 UTC`. Si ese fuera el respaldo más reciente disponible al ocurrir un incidente, el RPO real dependería de cuánto trabajo se hubiera realizado después de ese momento. El RTO dependería del tiempo necesario para restaurar el volumen, recrear el contenedor, arrancar Oracle y validar la base de datos.

**Evidencia:** `backups/20261024T185003Z_lab3-final/manifiesto.txt`, líneas 1–8.

El manifiesto no aporta mediciones de pérdida de datos ni de duración de una restauración completa; por ello, no permite asignar valores numéricos demostrados a RPO y RTO.

## 4. ¿Dónde creó Oracle los datafiles de V000 y por qué? ¿Qué parámetro lo habría evitado?

Los cinco datafiles de negocio quedaron inicialmente en:

`/opt/oracle/product/26ai/dbhomeFree/dbs/`

El diagnóstico inicial muestra allí `academia01.dbf`, `clinica01.dbf`, `retail01.dbf`, `logistica01.dbf` y `fintech01.dbf`. También registra que `DB_CREATE_FILE_DEST` estaba vacío, por lo que no había un destino OMF configurado.

Sin un destino predeterminado explícito ni una ruta completa especificada en la creación, Oracle acabó usando una ubicación asociada al entorno de la instancia.

**Evidencia:** `docs/bitacora/lab4/evidencia/script/20261025T200752Z_01-diagnostico.script.log`, líneas 27–37 y 46–74.

Para evitarlo, se puede configurar `DB_CREATE_FILE_DEST` con el directorio de destino deseado o especificar explícitamente la ruta completa del datafile al ejecutar `CREATE TABLESPACE`.

## 5. ¿Por qué `ALTER TABLESPACE ... RENAME DATAFILE` no basta para mover físicamente un archivo?

Porque el comando actualiza la ruta que Oracle registra para el datafile, pero no mueve por sí solo el archivo en el sistema operativo.

En este laboratorio se realizó el proceso completo: poner el tablespace fuera de línea, copiar físicamente el archivo conservando los permisos, actualizar la ruta registrada en Oracle, volver a poner el tablespace en línea y validar el resultado. La segunda ejecución informó que ya no había nada que reubicar.

**Evidencias:**
- `docs/bitacora/lab4/evidencia/script/20261025T201511Z_03-reubicar-datafiles.script.log`, pasos de reubicación.
- `docs/bitacora/lab4/evidencia/script/20261025T201615Z_03-reubicar-datafiles.script.log`, líneas 1–7.
- `docs/bitacora/lab4/evidencia/script/20261025T203020Z_03-prueba-persistencia.script.log`, líneas 39–41.

## 6. ¿Por qué no se debe editar V000 y se crea V003? ¿Por qué es mejor invalidar una contraseña que simplemente borrar el texto del archivo?

Una migración aplicada como `V000__setup_entornos_negocio.sql` debe conservarse como parte del historial reproducible del proyecto. Editarla después de aplicarla puede hacer que una instalación nueva y una base de datos ya existente terminen con estados diferentes. Una migración posterior, como V003, permite corregir el estado de forma explícita y ordenada.

En este laboratorio, V003 deja las cuentas `ADMIN_*` con `AUTHENTICATION_TYPE=NONE`. La verificación final confirma que no quedan cuentas `ADMIN_*` con contraseña.

Borrar una contraseña de un archivo no la elimina de los commits anteriores de Git ni de posibles copias. Si la credencial pudo quedar expuesta, hay que invalidarla o cambiarla para que deje de ser utilizable y, después, abordar la eliminación del secreto del historial y las demás exposiciones.

**Evidencias:**
- `database/migrations/V000__setup_entornos_negocio.sql`.
- `database/migrations/V003__cuentas_esquema_sin_password.sql`.
- `docs/bitacora/lab4/evidencia/spool/20261025T202157Z_04-V003__cuentas_esquema_sin_password.spool.log`, líneas 20–26.
- `docs/bitacora/lab4/evidencia/script/20261025T215153Z_10-verificacion-final.script.log`, verificación de cuentas sin contraseña.
- `docs/bitacora/lab3-respuestas.md`, líneas 122–126.

## 7. ¿Qué demuestra la prueba de persistencia y por qué se hace después de mover los datafiles?

La prueba comprueba que los datos sobreviven a la eliminación y recreación del contenedor porque están almacenados en el volumen persistente, no únicamente en la capa efímera del contenedor.

Se detuvo Oracle de forma ordenada, se eliminó el contenedor conservando el volumen `oralab-26ai-data` y se creó otro contenedor utilizando ese volumen. Después se comprobó que el datafile de `TBS_ACADEMIA` seguía en `/opt/oracle/oradata/FREE/FREEPDB1/academia01.dbf` y que el tablespace estaba disponible.

Se hace después de reubicar los archivos porque también verifica que las nuevas rutas y los archivos movidos continúan siendo accesibles al recrear el contenedor.

**Evidencia:** `docs/bitacora/lab4/evidencia/script/20261025T203020Z_03-prueba-persistencia.script.log`, especialmente líneas 22–31 y 39–41.

## 8. Explica la diferencia entre instancia y base de datos. Indica tres componentes de cada una.

La **instancia** es el conjunto de memoria y procesos de Oracle que gestionan el acceso a la base de datos. La **base de datos** es el conjunto de archivos físicos que almacenan la información y la estructura necesaria para recuperarla.

Tres componentes de la instancia son:
1. **SGA:** memoria compartida de la instancia.
2. **PGA:** memoria privada de los procesos.
3. **Procesos de Oracle:** por ejemplo, PMON, SMON y LGWR.

Tres componentes físicos de la base de datos son:
1. **Datafiles:** contienen los datos de los tablespaces.
2. **Control files:** registran información estructural y de control de la base.
3. **Redo log files:** registran los cambios necesarios para la recuperación.

**Evidencias de los procesos y la configuración:** `docs/bitacora/lab4/evidencia/spool/20261025T213845Z_09-procesos.spool.log` y `docs/bitacora/lab4/evidencia/spool/20261025T213057Z_08-memoria.spool.log`. Los archivos físicos se identifican también en `20261025T200752Z_01-diagnostico.script.log`.

## 9. ¿Qué puede consultarse en NOMOUNT, MOUNT y OPEN? ¿Qué significan ORA-01507 y ORA-01219?

- **NOMOUNT:** Oracle lee los parámetros de inicialización, asigna la memoria y arranca los procesos de la instancia. La base todavía no está montada.
- **MOUNT:** la instancia utiliza el control file para montar la base. Se puede consultar información de control, pero la base no está abierta para el acceso normal a los datos.
- **OPEN:** se abren los archivos de la base y se permite el acceso normal sujeto a permisos y al estado de cada contenedor.

En la evidencia, durante NOMOUNT, la consulta a `V$DATABASE` devuelve `ORA-01507: database not mounted`. Durante MOUNT, la consulta a `DBA_TABLES` devuelve `ORA-01219`, porque la base aún no está abierta para consultar esos datos.

**Evidencia:** `docs/bitacora/lab4/evidencia/script/20261025T210936Z_06-arranque-por-etapas.script.log`, líneas 14–40 (NOMOUNT), 44–67 (MOUNT) y 71–91 (OPEN).

Estos errores son coherentes con las etapas en que se ejecutaron las consultas; no demuestran por sí mismos corrupción de la base.

## 10. ¿Por qué FREEPDB1 se abre después de `ALTER DATABASE OPEN`? ¿Qué ocurriría si no lo hiciera?

Abrir la CDB no implica que todas las PDB tengan que quedar abiertas automáticamente en cualquier configuración. En el laboratorio, `FREEPDB1` queda en `READ WRITE` tras abrir la base, y la evidencia muestra que su estado se guarda para conservar esa apertura.

Si la PDB permaneciera cerrada, las conexiones y consultas dirigidas a ella no podrían utilizar sus objetos hasta abrirla, por ejemplo, con `ALTER PLUGGABLE DATABASE FREEPDB1 OPEN`. Para que vuelva a abrirse automáticamente tras reinicios, se puede guardar su estado con `ALTER PLUGGABLE DATABASE FREEPDB1 SAVE STATE`.

**Evidencia:** `docs/bitacora/lab4/evidencia/script/20261025T210936Z_06-arranque-por-etapas.script.log`, líneas 71–91.

## 11. Clasifica ORA-00800 y ORA-20013 en el alert log. ¿Son alertas reales o ruido conocido?

El alert log contiene `ORA-00800: soft external error [Set Priority Failed]` para los procesos VKTM y LGWR durante los arranques registrados. El mensaje indica que Oracle no pudo aplicar la prioridad de proceso solicitada al sistema operativo. En la evidencia, la instancia monta y abre la base después de estos mensajes, por lo que el fallo de prioridad no impidió el arranque observado. Aun así, no debe descartarse automáticamente: conviene revisar los traces y la configuración del sistema operativo.

También aparecen `ORA-27300`, `ORA-27301`, `ORA-27302` y `ORA-27303` asociados a un fallo de `chdir()` con “No such file or directory”.

La búsqueda realizada no encontró `ORA-20013` en los archivos de evidencia examinados. Por tanto, no hay base documental suficiente para clasificar ese error ni afirmar que sea ruido conocido en este laboratorio.

**Evidencia:** `docs/bitacora/lab4/evidencia/script/20261025T211522Z_06-alert-log.script.log`, líneas 1–11 y 32–49; búsqueda de errores en `docs/bitacora/lab4/evidencia` y `scripts/lab4`.

## 12. ¿Cuál es la diferencia entre V$PARAMETER y V$SPPARAMETER? Utiliza DB_FILES.

`V$PARAMETER` muestra los valores de los parámetros efectivos en la instancia actual. `V$SPPARAMETER` muestra los valores almacenados en el SPFILE, es decir, los que se utilizarán al arrancar según la configuración persistida.

La evidencia de `DB_FILES` muestra un valor efectivo de `200` y un valor en el SPFILE de `300`. Esto demuestra que el valor activo y el persistido pueden ser distintos: el SPFILE puede contener un cambio pendiente de reinicio o una configuración que todavía no coincide con el valor efectivo.

**Evidencias:**
- `docs/bitacora/lab4/evidencia/script/20261025T212227Z_07-parametros-cambios.script.log`, líneas 23–27.
- `docs/bitacora/lab4/evidencia/spool/20261025T211954Z_07-parametros-lectura.spool.log`, consultas a `V$PARAMETER` y `V$SPPARAMETER`.

## 13. ¿Qué hace SCOPE=BOTH y cuál es el ámbito predeterminado con SPFILE?

`SCOPE=BOTH` solicita que Oracle aplique el cambio tanto a la memoria de la instancia como al SPFILE, cuando el parámetro admite ambos ámbitos.

En el laboratorio, `open_cursors` cambia a `500` con `SCOPE=BOTH` y se observa el nuevo valor tanto en memoria como en el SPFILE. En cambio, con `SCOPE=MEMORY`, el valor cambia en la instancia, pero el valor persistido permanece en `300`.

Cuando la instancia usa un SPFILE, el ámbito predeterminado de `ALTER SYSTEM SET` es `BOTH` para los parámetros que permiten ese ámbito; aun así, especificarlo explícitamente hace más clara la intención. No todos los parámetros admiten todos los valores de `SCOPE`.

**Evidencia:** `docs/bitacora/lab4/evidencia/script/20261025T212227Z_07-parametros-cambios.script.log`, líneas 2–12.

## 14. ¿Por qué PROCESSES rechaza el cambio en memoria si V$PARAMETER indica IMMEDIATE?

La vista muestra `PROCESSES` con `ISSYS_MODIFIABLE=IMMEDIATE`, pero la prueba de cambio a `250` con `SCOPE=MEMORY` devuelve `ORA-02097` y `ORA-02095`. Por tanto, la evidencia demuestra que el intento concreto fue rechazado por Oracle, aunque la columna consultada indique `IMMEDIATE`.

No conviene concluir únicamente a partir de esa columna que cualquier cambio de valor y contexto va a ser aceptado. Hay que considerar la versión, las restricciones del parámetro y el contexto de ejecución. La prueba separada ejecutada desde `FREEPDB1` devuelve `ORA-65040` al intentar cambiar `processes` con `SCOPE=SPFILE`, porque esa operación no está permitida desde una PDB.

**Evidencia:** `docs/bitacora/lab4/evidencia/script/20261025T212227Z_07-parametros-cambios.script.log`, líneas 37–43 y 58–65.

## 15. ¿Por qué versionar el PFILE y qué es la deriva de configuración?

Versionar un PFILE permite documentar y revisar los valores de configuración deseados, comparar cambios entre versiones y reconstruir la intención de configuración del laboratorio.

La **deriva de configuración** ocurre cuando la configuración efectiva o persistida se separa de la configuración declarada y mantenida en los archivos versionados. Por ejemplo, un cambio manual en el SPFILE que no se refleje en el PFILE del repositorio puede generar esa diferencia.

En el laboratorio se guardan dos archivos de configuración como evidencia: `initFREE_lab4.ora` e `initFREE_lab4_memoria.ora`. El SPFILE es el archivo binario utilizado por Oracle; el PFILE permite mantener una representación textual que se puede revisar en Git.

**Evidencia:** `docs/bitacora/lab4/evidencia/config/initFREE_lab4.ora`, `docs/bitacora/lab4/evidencia/config/initFREE_lab4_memoria.ora` y `docs/bitacora/lab4/evidencia/script/20261025T212408Z_07-pfile.script.log`.

## 16. ¿Qué modelo de gestión de memoria utiliza la instancia? Explica tres parámetros.

La instancia utiliza **Automatic Shared Memory Management (ASMM)** para gestionar automáticamente la distribución de la SGA. La evidencia muestra `SGA_TARGET=1536M`, `SGA_MAX_SIZE=1536M` y `MEMORY_TARGET=0`. La PGA se gestiona por separado.

Tres parámetros relevantes son:

- `SGA_TARGET=1536M`: establece el objetivo de tamaño de la SGA.
- `PGA_AGGREGATE_TARGET=512M`: establece el objetivo de memoria PGA agregada.
- `PGA_AGGREGATE_LIMIT=2G`: fija el límite de memoria PGA agregada.

`DB_CACHE_SIZE=0` y `SHARED_POOL_SIZE=0` indican que no se ha establecido un tamaño explícito distinto de cero para esos componentes; no significan que no consuman memoria. La evidencia de los componentes dinámicos muestra un buffer cache de aproximadamente `928 MB` y un shared pool de `480 MB` en la medición registrada.

**Evidencia:** `docs/bitacora/lab4/evidencia/spool/20261025T213057Z_08-memoria.spool.log`, líneas 7–14, 29–32 y 47–52.

## 17. ¿Qué demuestra el experimento de caché? Incluye los resultados.

Se ejecutó la misma consulta de estudiantes activos dos veces. En ambas rondas se obtuvieron `17.600` filas activas, pero las lecturas físicas fueron diferentes:

| Medición | Ronda 1: caché fría | Ronda 2: caché caliente |
|---|---:|---:|
| Filas activas | 17.600 | 17.600 |
| Lecturas lógicas | 355 | 247 |
| Lecturas físicas | 261 | 0 |

La segunda ejecución no necesitó lecturas físicas registradas para esa sesión y consulta, porque los bloques necesarios estaban disponibles en memoria. Sin embargo, siguió teniendo lecturas lógicas: Oracle todavía debe acceder a los bloques de datos a través del buffer cache.

La tabla ocupaba `244` bloques según `DBA_TABLES`, mientras que la consulta a `V$BH` registró `245` bloques de ese objeto en caché. Esas cifras provienen de vistas y mediciones diferentes y no deben interpretarse como si fueran necesariamente idénticas.

**Evidencia:** `docs/bitacora/lab4/evidencia/script/20261025T213226Z_08-experimento-cache.script.log`, líneas 4–18.

## 18. ¿Por qué no se debe sumar el RSS de los procesos para calcular la memoria de la instancia Oracle?

El RSS indica la memoria residente asignada a cada proceso, pero no es una medida directa de la memoria total utilizada exclusivamente por la instancia Oracle.

Varios procesos pueden mapear páginas compartidas de la SGA. Sumar sus RSS puede contar esas mismas páginas varias veces. Además, el RSS no equivale a la suma de SGA y PGA, ni permite separar de manera fiable toda la memoria de Oracle de otros usos del sistema operativo.

Para analizar la memoria de la instancia es preferible consultar las vistas de memoria de Oracle y utilizar las métricas del sistema operativo como información complementaria, teniendo en cuenta sus diferencias.

**Evidencias:** `docs/bitacora/lab4/evidencia/spool/20261025T213057Z_08-memoria.spool.log` y `docs/bitacora/lab4/evidencia/script/20261025T214416Z_09-procesos-so.script.log`.

## 19. ¿Cómo se relaciona el SPID de LGWR con el PID de Linux? ¿Por qué puede variar lo que muestra Docker?

`V$PROCESS.SPID` identifica el proceso del sistema operativo asociado al proceso de Oracle. En la evidencia, LGWR tiene el SPID `2938`, y el listado del sistema operativo muestra el proceso `db_lgwr_FREE` con PID `2938`. Ambos identifican el proceso de LGWR en esa medición.

Docker puede mostrar PID diferentes según si se observa desde el host o desde el espacio de nombres de procesos del contenedor. Por eso, los PID solo deben compararse teniendo en cuenta el entorno desde el que se obtuvieron y el momento de la medición.

LGWR escribe las entradas de redo desde el redo log buffer hacia los archivos redo log. En un `COMMIT` normal, Oracle espera a que el redo necesario para confirmar la transacción se haya escrito de forma duradera antes de devolver la confirmación.

**Evidencias:**
- `docs/bitacora/lab4/evidencia/spool/20261025T213845Z_09-procesos.spool.log`, líneas 15–21.
- `docs/bitacora/lab4/evidencia/script/20261025T214416Z_09-procesos-so.script.log`, líneas 1–18.

## 20. ¿Qué hacen PMON y SMON? Da un ejemplo de cada uno.

**PMON (Process Monitor)** realiza tareas de limpieza relacionadas con procesos que terminan de forma anormal. Por ejemplo, puede limpiar recursos de una sesión cuyo proceso servidor ha fallado.

**SMON (System Monitor)** realiza tareas de recuperación de la instancia cuando son necesarias y otras labores de limpieza del sistema. Por ejemplo, participa en la recuperación tras una caída de la instancia, aplicando los cambios necesarios para restablecer la consistencia.

No son intercambiables: PMON se asocia especialmente con la limpieza de procesos y recursos, mientras que SMON participa en la recuperación de la instancia.

**Evidencia de los procesos de Oracle observados:** `docs/bitacora/lab4/evidencia/spool/20261025T213845Z_09-procesos.spool.log`, líneas 15–21.

## 21. ¿Por qué se creó C##OPS_RO en vez de utilizar SYSTEM? ¿Qué no debería poder hacer?

`C##OPS_RO` se creó como cuenta común de observabilidad con privilegios explícitos para conectarse, cambiar de contenedor y consultar vistas de catálogo. Utilizar una cuenta específica para observabilidad aplica el principio de mínimo privilegio mejor que utilizar `SYSTEM`, una cuenta administrativa con capacidades mucho más amplias.

El script concede `CREATE SESSION`, `SET CONTAINER`, `SELECT_CATALOG_ROLE` y configura `CONTAINER_DATA`. No concede explícitamente privilegios para insertar, actualizar o eliminar datos de las aplicaciones ni para crear, modificar o eliminar sus objetos.

La limitación debe expresarse con precisión: `SELECT_CATALOG_ROLE` permite un acceso amplio de lectura al catálogo, y los privilegios efectivos dependen también de otros permisos existentes. La evidencia confirma las concesiones realizadas, no una prueba exhaustiva de que todas las operaciones administrativas posibles estén bloqueadas.

**Evidencias:**
- `scripts/lab4/02-cuenta-observabilidad.sql`, líneas 8–19.
- `docs/bitacora/lab4/evidencia/script/20261025T215153Z_10-verificacion-final.script.log`, verificación de `C##OPS_RO`.

## 22. ¿Qué dos vías de exposición de contraseñas se han tratado respecto a Lab 3?

Dos vías importantes son:

1. **Exposición en Git:** escribir una contraseña en un script o archivo versionado puede hacer que termine en el repositorio y en el historial de commits. Borrar el texto en un commit posterior no elimina las versiones anteriores; si el secreto pudo exponerse, debe cambiarse o invalidarse.
2. **Exposición en comandos o evidencias:** escribir una contraseña directamente en un comando puede dejarla en el historial de la shell, en registros o en capturas de terminal, aunque el script no se suba a Git.

El enfoque aplicado es mantener las credenciales reales en `config/.env`, excluido del repositorio, y utilizar variables para proporcionarlas a los scripts. Por ejemplo, el script de observabilidad utiliza `&&ops_pwd` en lugar de incluir una contraseña fija en el SQL.

**Evidencias:**
- `docs/bitacora/lab3-respuestas.md`, líneas 110–124.
- `scripts/lab4/02-cuenta-observabilidad.sql`, líneas 10–13.
- `docs/bitacora/lab4/evidencia/script/20261025T215153Z_10-verificacion-final.script.log`, verificaciones finales de configuración y secretos.

---

## Verificación final del laboratorio

La verificación final informa `RESULTADO: TODO OK`. Entre los resultados registrados se encuentran:

- Cinco tablespaces de negocio.
- Cero datafiles de negocio fuera de `FREEPDB1`.
- Cero archivos con rutas reales fuera del volumen.
- Cero cuentas `ADMIN_*` con contraseña.
- Datos de demostración: 20.000 estudiantes, 40 asignaturas y 60.000 matrículas.
- CDB y `FREEPDB1` en `READ WRITE`.
- `C##OPS_RO` verificada como cuenta común.
- `open_cursors` restaurado a `300`.
- Evidencias generadas y archivos de configuración y secretos comprobados.

**Evidencia:** `docs/bitacora/lab4/evidencia/script/20261025T215153Z_10-verificacion-final.script.log`, líneas 1–32.
