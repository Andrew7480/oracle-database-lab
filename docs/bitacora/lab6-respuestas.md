# Lab 6 — Respuestas y análisis de evidencias

Documento de trabajo para organizar las evidencias del Lab 6 y responder las preguntas de comprobación y tipo examen.

## Índice

1. [Prácticas SRE](#prácticas-sre)
2. [Preguntas de comprobación](#preguntas-de-comprobación)
   - [Partes A-C: rol operativo, parámetros y estados](#91-partes-a-c--rol-operativo-parámetros-y-estados)
   - [Partes D-E: servicios, sesiones y diccionario](#911-partes-d-e--servicios-sesiones-y-diccionario)
   - [Partes F-G: espacio y acceso](#912-partes-f-g--espacio-y-acceso)
   - [Partes H-I: objetos, diagnóstico y guardia](#913-partes-h-i--objetos-diagnóstico-y-guardia)
3. [Preguntas tipo examen](#preguntas-tipo-examen)

## PRÁCTICAS SRE

1. **Recuento de errores ORA- de hoy:** 6. Archivo: 20261125T104628Z_01-turno.script.log.
2. **Errores de este arranque y sus causas** ([evidencia](/docs/bitacora/lab6/evidencia/script/20261125T111525Z_02-estados-pdb.script.log)):

   - **ORA-16000:** Se intenta ejecutar un UPDATE sobre ACA_ESTUDIANTES mientras FREEPDB1 está abierta en modo READ ONLY, donde solo se permiten consultas.

   - **ORA-65019:** Se intenta abrir FREEPDB1 en READ WRITE cuando ya está abierta en READ ONLY; para cambiar de modo sin cerrarla antes se necesita la cláusula FORCE.

   - **ORA-01035:** Un usuario normal de monitorización (C##OPS_RO) intenta conectarse mientras FREEPDB1 está en modo restringido, acceso reservado solo a cuentas con el privilegio RESTRICTED SESSION.

   - **ORA-01109:** Al reiniciar la instancia sin haber guardado el estado de la PDB (SAVE STATE), FREEPDB1 queda en estado MOUNTED y rechaza conexiones de aplicación o lectura.

## Preguntas de comprobación

Respóndelas con tus propias palabras y cita la evidencia (archivo y valor). Una respuesta sin una cifra de tu ejecución no puntúa.
### 9.1. Partes A-C · Rol operativo, parámetros y estados
1. ¿Cuántos errores ORA- tenía tu alert log en 24 h en la Parte B y a qué se debían? ¿Por qué ese número no es una alarma por sí solo?
**Respuesta:** El recuento fue de 6h. La salida de turno guarda el total, pero no el detalle de esos seis errores; hace falta consultar el alert log para atribuirles causas. El número aislado no basta para declarar una alarma: hay que compararlo con la línea base, la recurrencia, la gravedad y el impacto. ([turno](lab6/evidencia/script/20261125T104628Z_01-turno.script.log))

2. ¿A qué hora empieza y cuánto dura la ventana de mantenimiento de un miércoles en tu base? ¿Qué tareas automáticas corren en ella?
**Respuesta:** La ventana del miércoles empieza a las 22:00 y dura 4 horas. En ella están habilitadas la recopilación automática de estadísticas, el asesor de espacio y el asesor de ajuste SQL. ([automatización](lab6/evidencia/spool/20261125T105130Z_01-automatizacion.spool.log))

3. Explica con tu salida de la Parte C la diferencia entre lo que mostraban V$SPPARAMETER y V$PARAMETER tras el SCOPE = SPFILE. ¿Qué habría pasado en el siguiente reinicio sin el RESET?
**Respuesta:** Tras SCOPE = SPFILE, V$SPPARAMETER mostraba db_files = 250, mientras V$PARAMETER seguía en 200: el cambio estaba guardado para el próximo arranque, pero aún no estaba activo. Sin RESET, el siguiente reinicio habría aplicado 250. ([parámetros](lab6/evidencia/script/20261125T110549Z_02-parametros.script.log))
4. ¿Por qué RESET fue la vuelta atrás correcta para db_files y no lo habría sido para processes? Cita la línea de
tu PFILE que lo demuestra.
**Respuesta:** db_files no tenía un valor propio en el PFILE, así que RESET quitó la modificación añadida. En cambio, el PFILE sí fija processes=200; resetearlo habría eliminado ese valor configurado. ([PFILE](lab6/evidencia/config/20261125T111015Z_02-init_desde_spfile.ora))

5. Tras el reinicio sin estado guardado, ¿qué error obtuvo C##OPS_RO y por qué la instancia decía «Database
opened»?
**Respuesta:** C##OPS_RO obtuvo ORA-01109 porque FREEPDB1 estaba MOUNTED, no abierta. Database opened se refiere a la base contenedora; no significa que la PDB también se haya abierto. ([estados de PDB](lab6/evidencia/script/20261125T111525Z_02-estados-pdb.script.log))

### 9.1.1. Partes D-E · Servicios, sesiones y diccionario
6. ¿Qué SID, SPID y evento tenía la sesión de la aplicación en tu ejecución? ¿Qué te dicen MODULE, ACTION y
CLIENT_IDENTIFIER que no te diría USERNAME?
**Respuesta:** La sesión tenía SID 51, SPID 7315 y esperaba en PL/SQL lock time. USERNAME identifica la cuenta APP_ACADEMIA; MODULE=matriculas ACTION=cierre-periodo y CLIENT_IDENTIFIER=ana.garcia@ucam dan contexto sobre la aplicación, la operación y la persona asociada. ([sesiones](lab6/evidencia/script/20261125T115610Z_03-sesiones.script.log))
7. Tras CANCEL SQL, ¿cuántas transacciones abiertas tenía la aplicación? ¿Y tras KILL SESSION? ¿En qué
estado quedó la fila 101 y por qué?
**Respuesta:** Después de CANCEL SQL seguía abierta 1 transacción. Tras KILL SESSION quedó 0 sesiones de la aplicación y la transacción se deshizo. la fila 101 quedó ACTIVO, el valor anterior al UPDATE sin confirmar. ([sesiones](lab6/evidencia/script/20261125T115610Z_03-sesiones.script.log))
8. ¿Qué valor tiene common_user_prefix en tu imagen? ¿Qué implica para el nombre de una cuenta común?
**Respuesta:** El valor es C##; las cuentas comunes creadas por el usuario deben llevar ese prefijo. ([cuenta de aplicación](lab6/evidencia/script/20261125T113635Z_03-cuenta-app.script.log))
9. Completa con tus cifras la tabla de las tres miradas (ALL_TABLES, DBA_USERS, CDB_USERS, V$DATAFILE)
y explica una diferencia.
**Respuesta:**

| Conexión | ALL_TABLES de ADMIN_ACADEMIA | DBA_USERS | CDB_USERS | V$DATAFILE |
|---|---:|---:|---|---:|
| C##OPS_RO en CDB$ROOT | 0 | 37 | CON_ID 1: 37; CON_ID 3: 47 | 17 |
| C##OPS_RO en FREEPDB1 | 0 | 47 | CON_ID 3: 47 | 10 |
| APP_ACADEMIA en FREEPDB1 | 1 | ORA-00942 | ORA-00942 | ORA-00942 |

Desde la raíz, C##OPS_RO ve usuarios de ambos contenedores por CONTAINER_DATA=ALL, desde FREEPDB1 solo los del contenedor actual. APP_ACADEMIA no tiene acceso a esas vistas de catálogo. ([tres miradas](lab6/evidencia/script/20261125T140641Z_04-tres-miradas.script.log))
10. Con tu salida de 04-deltas: ¿cuántas lecturas lógicas por recorrido y cuánto DB time costó la carga? ¿Qué
indica la relación entre DB time y DB CPU?
**Respuesta:** Fueron 5389 lecturas lógicas por recorrido, la carga registró 0,87 s de DB time y 0,88 s de DB CPU. Son valores prácticamente iguales, lo que indica que el tiempo medido se consumió casi todo en CPU y hubo poca espera, la diferencia de 0,01 s puede deberse al redondeo de las métricas. ([deltas](lab6/evidencia/script/20261125T140932Z_04-deltas.script.log))
### 9.1.2. Partes F-G · Espacio y acceso
11. Da las tres medidas (asignado, libre, máximo) de TBS_ACADEMIA_HIST antes de la carga y explica cuál
usarías para alertar.
**Respuesta:** Antes de la carga tenía 10 MB asignados, 3,9 MB libres y un máximo de 40 MB. Para alertar usaría el porcentaje utilizado respecto al máximo alcanzable; la práctica fija aviso en 80 % y crítico en 95 %. ([almacenamiento](lab6/evidencia/script/20261125T141230Z_05-almacenamiento.script.log))
12. ¿Quién insertó y quién «pagó» en el ORA-01950? ¿Por qué ampliar el tablespace no habría resuelto el ORA01536?
**Respuesta:** La sentencia la ejecutó la sesión administrativa del script CARGA_HIST necesitaba la cuota y recibió ORA-01950. El tablespace tenía espacio libre, pero al agotarse la cuota de 2 MB de CARGA_HIST se produjo ORA-01536, añadir espacio al tablespace no aumenta la cuota del usuario. ([almacenamiento](lab6/evidencia/script/20261125T141230Z_05-almacenamiento.script.log))
13. ¿Cuánto tiempo estuvo suspendida la carga reanudable y qué evidencia de ello dejó Oracle en el alert log?
**Respuesta:** Aproximadamente 15 segundos, desde las 14:13:57 hasta las 14:14:12. Oracle registró en el alert log que la sentencia reanudable fue suspendida y luego reanudada. El estado SUSPENDED y ORA-01536 también aparecen en la consulta. ([carga reanudable](lab6/evidencia/script/20261125T141356Z_05-resumable.script.log))
14. Antes y después del SHRINK: filas, bloques y cuota consumida. ¿Por qué un DELETE no devolvió el espacio?
**Respuesta:** Antes del SHRINK quedaban 2000 filas, 2944 bloques y 23 MB consumidos; después, 2000 filas, 304 bloques y 2,4 MB. El DELETE quitó filas, pero no redujo el segmento ni su HWM, SHRINK SPACE compactó las filas y liberó espacio. ([HWM y shrink](lab6/evidencia/script/20261125T141449Z_05-hwm-shrink.script.log))
15. ¿Qué valores tenía tu perfil DEFAULT? Justifica dos de los límites de PRF_PERSONAS para una persona de
secretaría.
**Respuesta:** DEFAULT tenía FAILED_LOGIN_ATTEMPTS=10, INACTIVE_ACCOUNT_TIME=365, PASSWORD_GRACE_TIME=7, PASSWORD_LIFE_TIME=180, PASSWORD_LOCK_TIME=1, PASSWORD_REUSE_MAX=UNLIMITED, PASSWORD_REUSE_TIME=UNLIMITED, PASSWORD_ROLLOVER_TIME=0 y PASSWORD_VERIFY_FUNCTION=NULL. En PRF_PERSONAS, 3 intentos fallidos limitan intentos repetidos y el bloqueo de 1 minuto aplica una pausa breve tras alcanzarlos, la verificación de contraseña también exige complejidad. ([gobierno y acceso](lab6/evidencia/script/20261125T171553Z_06-gobierno-acceso.script.log); [perfil](../../scripts/lab6/06-gobierno-acceso.sql))
16. ¿Por qué Ana pudo leer ACA_MATRICULAS si nadie se la concedió por nombre? ¿Qué error obtuvo al
cambiar el nombre de un alumno?
**Respuesta:** Ana heredó SELECT ANY TABLE ON SCHEMA ADMIN_ACADEMIA mediante sus roles, así que pudo leer ACA_MATRICULAS sin una concesión directa por nombre. Al intentar cambiar NOMBRES obtuvo ORA-41900, porque solo tenía UPDATE sobre la columna ESTADO. ([prueba de acceso](lab6/evidencia/script/20261125T171712Z_06-probar-acceso.script.log))
### 9.1.3. Partes H-I · Objetos, diagnóstico y guardia
17. ¿Qué objetos se invalidaron en cada uno de los tres cambios de columna y por qué no se invalidó nada con
la columna nueva?
**Respuesta:** Añadir una columna no invalidó objetos, ampliar EMAIL_INSTITUCIONAL invalidó V_CONTACTO_LAB6, ampliar NOMBRES invalidó V_ACTIVOS_LAB6 y F_TOTAL_ACTIVOS_LAB6 por sus dependencias. La columna nueva no tenía dependencias existentes. ([objetos](lab6/evidencia/script/20261125T172625Z_07-objetos.script.log))
18. Según tus advisors, ¿mejoraría el DB time duplicar la SGA? ¿Y por debajo de qué tamaño la PGA tendría
sobreasignaciones?
**Respuesta:** No: duplicar la SGA de 1536 a 3072 MB dejó el factor estimado de DB time en 1. Para la PGA hubo sobreasignaciones con 128 y 256 MB; a partir de 384 MB el advisor estimó 0 sobreasignaciones. ([memoria](lab6/evidencia/script/20261125T172732Z_07-memoria.script.log))
19. ¿Cuántas lecturas lógicas necesitó la consulta de la aplicación según la traza (o tkprof)? ¿Qué línea de la
traza lo dice?
**Respuesta:** Necesitó 247 lecturas lógicas. Lo indica cr=247, tkprof también muestra query=247 en la fila de Fetch. ([ADR y trazas](lab6/evidencia/script/20261125T173057Z_07-adr-trazas.script.log))
20. Para cada incidente de la guardia: evidencia clave, intervención y validación (una línea por cada uno).
**Respuesta:**
- **INC-601:** 1 sesión bloqueada por SID 68 de APP_ACADEMIA; se terminó esa sesión y se validó que no quedaran bloqueos y que el alumno 101 siguiera ACTIVO. ([diagnóstico](lab6/evidencia/script/20261125T234952Z_08-inc1-diagnostico-antes.script.log), [intervención](lab6/evidencia/script/20261125T235030Z_08-inc1-actuar.script.log), [diagnóstico posterior](lab6/evidencia/script/20261125T235148Z_08-inc1-diagnostico-despues.script.log), [validación del alumno](lab6/evidencia/script/20261125T235150Z_08-inc1-validar-alumno.script.log))
- **INC-602:** academia_app estaba detenido aunque la PDB seguía abierta; se inició con DBMS_SERVICE.START_SERVICE y se validó que apareciera arrancado y registrado. ([diagnóstico](lab6/evidencia/script/20261126T002521Z_08-inc2-diagnostico-antes.script.log), [intervención](lab6/evidencia/script/20261126T003447Z_08-inc2-actuar.script.log), [validación](lab6/evidencia/script/20261126T003510Z_08-inc2-diagnostico-despues.script.log))
- **INC-603:** APP_ACADEMIA estaba LOCKED y causaba ORA-28000; se desbloqueó la cuenta y se validó que regresara a OPEN. ([diagnóstico](lab6/evidencia/script/20261126T004548Z_08-inc3-diagnostico-antes.script.log), [intervención](lab6/evidencia/script/20261126T005035Z_08-inc3-actuar.script.log), [validación](lab6/evidencia/script/20261126T005040Z_08-inc3-diagnostico-despues.script.log))



## Preguntas tipo examen

**B1.** En una PDB, DBA_TABLESPACE_THRESHOLDS muestra NONE para el tablespace de la aplicación. ¿Qué
significa?
- **A.** Que el tablespace está vacío.
- **B.** Que MMON no generará alertas de espacio para ese tablespace hasta que se fije un umbral.
- **C.** Que se aplica el umbral del 85 % definido en la raíz.
- **D.** Que el tablespace es de solo lectura.
**Respuesta: B.** NONE indica que no hay un umbral configurado para ese tablespace; por tanto, no se generará una alerta de umbral hasta definirlo.

**C1.** Ejecutas ALTER SYSTEM SET db_files = 300 SCOPE = MEMORY y obtienes ORA-02095. ¿Qué cambio
aplica el valor en el próximo arranque sin afectar a la instancia actual?
- **A.** ALTER SYSTEM SET db_files = 300 SCOPE = BOTH;
- **B.** ALTER SYSTEM SET db_files = 300 SCOPE = SPFILE;
- **C.** ALTER SESSION SET db_files = 300;
- **D.** ALTER SYSTEM RESET db_files SCOPE = MEMORY;
**Respuesta: B.** SCOPE = SPFILE guarda el valor para el siguiente arranque, sin cambiar el valor activo de la instancia.

**C2.** Tras reiniciar el CDB, FREEPDB1 aparece en MOUNTED. ¿Qué dos acciones hacen que, a partir de ahora,
se abra sola tras cada reinicio? (Elige dos.)
- **A.** ALTER PLUGGABLE DATABASE freepdb1 OPEN;
- **B.** ALTER SYSTEM SET pdb_open = TRUE SCOPE = SPFILE;
- **C.** ALTER PLUGGABLE DATABASE freepdb1 SAVE STATE; (con la PDB ya abierta)
- **D.** ALTER PLUGGABLE DATABASE freepdb1 DISCARD STATE;
- **E.** ALTER DATABASE OPEN RESETLOGS;
**Respuesta: A y C.** Primero se abre la PDB y luego SAVE STATE persiste su estado para que se restaure tras los reinicios.

**D1.** Una sesión de la aplicación ejecuta una consulta que lleva 40 minutos y tiene una transacción pendiente que
no quieres perder. ¿Qué haces primero?
- **A.** ALTER SYSTEM KILL SESSION con IMMEDIATE.
- **B.** ALTER SYSTEM CANCEL SQL sobre esa sesión.
- **C.** kill -9 del SPID en Linux.
- **D.** SHUTDOWN IMMEDIATE
**Respuesta: B.** Cancela la llamada SQL activa sin terminar la sesión, preservando la transacción pendiente para decidir después cómo cerrarla.

**E1.** C##OPS_RO tiene SELECT_CATALOG_ROLE y CONTAINER_DATA = ALL. Conectado por el servicio
freepdb1 consulta CDB_USERS. ¿Qué ve?
- **A.** Los usuarios de todos los contenedores.
- **B.** Solo los usuarios de FREEPDB1.
- **C.** Un error, porque CDB_USERS solo existe en la raíz.
- **D.** Los usuarios de la raíz y de FREEPDB1, pero no los de PDB$SEED.
**Respuesta: B.** Al consultar desde una PDB, la vista de contenedores muestra los datos visibles del contenedor actual; CONTAINER_DATA = ALL no amplía desde ahí la consulta a todo el CDB.

**F1.** El usuario APP inserta en la tabla HIST.REGISTRO y recibe ORA-01536 sobre TBS_HIST, que tiene 500 MB
libres. ¿Qué lo resuelve con el menor cambio?
- **A.** ALTER TABLESPACE tbs_hist ADD DATAFILE ... SIZE 1G;
- **B.** ALTER USER app QUOTA 100M ON tbs_hist;
- **C.** ALTER USER hist QUOTA 100M ON tbs_hist;
- **D.** GRANT UNLIMITED TABLESPACE TO app;
**Respuesta: C.** La cuota se aplica al propietario del segmento (HIST), que es quien necesita espacio para ampliar su tabla; el espacio libre del tablespace no sustituye la cuota.

**G1.** El usuario A recibió CREATE TABLE WITH ADMIN OPTION y SELECT ON hr.emp WITH GRANT OPTION, y
concedió ambos a B. El DBA revoca ambos a A. ¿Qué conserva B?
- **A.** Ambos privilegios.
- **B.** Solo CREATE TABLE.
- **C.** Solo SELECT ON hr.emp.
- **D.** Ninguno.
**Respuesta: C.** La revocación del privilegio de sistema no se propaga en cascada, mientras que revocar el privilegio de objeto concedido con GRANT OPTION sí lo retira de B.

**G2.** ¿Qué hace GRANT SELECT ANY TABLE ON SCHEMA ventas TO rol_lectura en 23ai/26ai?
- **A.** Permite leer cualquier tabla de la base.
- **B.** Permite leer todas las tablas actuales y futuras del esquema VENTAS, y solo de ese esquema.
- **C.** Permite leer las tablas actuales de VENTAS, pero no las que se creen después.
- **D.** Es un error de sintaxis: los privilegios ANY no admiten ON.
**Respuesta: B.** El privilegio de esquema limita el acceso a los objetos del esquema VENTAS e incluye las tablas que se creen allí posteriormente.

**H1.** Tras un ALTER TABLE pedidos MOVE, las consultas por cliente van lentas pero nadie ve errores. ¿Qué es lo
más probable?
- **A.** La tabla quedó en estado INVALID.
- **B.** Los índices de la tabla quedaron UNUSABLE y el optimizador los ignora.
- **C.** Se perdieron las estadísticas del diccionario.
- **D.** El MOVE dejó la tabla en otro tablespace de solo lectura.
**Respuesta: B.** Un MOVE sin UPDATE INDEXES puede dejar los índices UNUSABLE; hay que reconstruirlos para que vuelvan a ser utilizables.

**S1.** ¿Qué proceso genera las alertas de umbral de espacio de los tablespaces?
- **A.** SMON
- **B.** MMON
- **C.** CJQ0
- **D.** LGWR
**Respuesta: B.** MMON supervisa los umbrales de espacio y genera las alertas correspondientes.

**S2.** Un parámetro tiene ISSYS_MODIFIABLE = DEFERRED. ¿Qué ocurre con ALTER SYSTEM SET ...
DEFERRED SCOPE = BOTH?
- **A.** Cambia para todas las sesiones de inmediato.
- **B.** Solo se aplica en el próximo arranque.
- **C.** Se aplica a las sesiones que se conecten a partir de ese momento.
- **D.** Da ORA-02095.
**Respuesta: C.** DEFERRED hace que el nuevo valor rija para las sesiones nuevas, no para las que ya están conectadas.

**S3.** ¿Qué sentencia crea una copia de texto de los parámetros en uso, incluidos los calculados por Oracle?
- **A.** CREATE PFILE FROM SPFILE;
- **B.** CREATE PFILE FROM MEMORY;
- **C.** CREATE SPFILE FROM PFILE;
- **D.** ALTER SYSTEM DUMP PARAMETERS;
**Respuesta: B.** CREATE PFILE FROM MEMORY genera un archivo de texto a partir de los parámetros en memoria, incluidos los valores calculados.

**S4.** Una PDB está abierta en READ ONLY. ¿Qué dos sentencias la dejan en READ WRITE? (Elige dos.)
- **A.** ALTER PLUGGABLE DATABASE pdb OPEN READ WRITE;
- **B.** ALTER PLUGGABLE DATABASE pdb OPEN READ WRITE FORCE;
- **C.** ALTER PLUGGABLE DATABASE pdb CLOSE IMMEDIATE; seguida de ALTER PLUGGABLE DATABASE pdb OPEN;
- **D.** ALTER PLUGGABLE DATABASE pdb SAVE STATE;
- **E.** ALTER DATABASE pdb READ WRITE;
**Respuesta: B y C.** FORCE permite reabrirla directamente en otro modo; alternativamente, se cierra y se vuelve a abrir en modo de lectura y escritura.

**S5.** ¿Qué vista muestra el estado que se guardó para cada PDB?
- **A.** V$PDBS
- **B.** DBA_PDBS
- **C.** DBA_PDB_SAVED_STATES
- **D.** V$CONTAINERS
**Respuesta: C.** DBA_PDB_SAVED_STATES muestra el modo de apertura guardado para cada PDB.

**S6.** Un usuario sin el privilegio RESTRICTED SESSION intenta conectarse a una PDB abierta en modo restringido.
¿Qué obtiene?
- **A.** ORA-01109
- **B.** ORA-01035
- **C.** ORA-12514
- **D.** ORA-28000
**Respuesta: B.** ORA-01035 indica que la base está en modo restringido y el usuario no tiene autorización para conectarse en ese modo.

**S7.** ¿Qué paquete crea y arranca un servicio en una base sin Grid Infrastructure?
- **A.** DBMS_SERVICE
- **B.** DBMS_SCHEDULER
- **C.** DBMS_MONITOR
- **D.** DBMS_SESSION
**Respuesta: A.** DBMS_SERVICE permite crear y administrar servicios de base de datos en este entorno.

**S8.** ¿Qué columnas unen V$SESSION con V$PROCESS?
- **A.** SID = PID
- **B.** PADDR = ADDR
- **C.** TADDR = ADDR
- **D.** SERIAL# = SPID
**Respuesta: B.** V$SESSION.PADDR apunta a la dirección del proceso correspondiente en V$PROCESS.ADDR.

**S9.** ¿Qué ocurre con la transacción pendiente de una sesión al ejecutar ALTER SYSTEM CANCEL SQL sobre
ella?
- **A.** Se confirma.
- **B.** Se deshace.
- **C.** Sigue abierta: solo se cancela la llamada en curso.
- **D.** Se convierte en una transacción autónoma
**Respuesta: C.** Cancelar la llamada SQL no equivale a terminar la sesión ni a confirmar o deshacer automáticamente su transacción.

**S10.** Te conectas como SYSOPER. ¿Qué devuelve SHOW USER?
- **A.** SYS
- **B.** SYSOPER
- **C.** PUBLIC
- **D.** SYSTEM
**Respuesta: C.** Una conexión administrativa con el privilegio SYSOPER se identifica como PUBLIC, no como el usuario SYS.

**S11.** Conectado a una PDB, ¿qué vista te da las métricas del último minuto de esa PDB?
- **A.** V$SYSMETRIC
- **B.** V$CON_SYSMETRIC
- **C.** V$METRICNAME
- **D.** DBA_HIST_SYSMETRIC_SUMMARY
**Respuesta: B.** V$CON_SYSMETRIC presenta las métricas del contenedor actual, incluido el intervalo más reciente.

**S12.** ¿Qué dos componentes suma DB time? (Elige dos.)
- **A.** Tiempo de CPU en llamadas a la base
- **B.** Tiempo de los procesos de fondo
- **C.** Tiempo de espera no Idle de las sesiones de primer plano
- **D.** Tiempo de las sesiones inactivas (Idle)
- **E.** Tiempo de parse de los procesos de fondo
**Respuesta: A y C.** DB time suma el tiempo de CPU de las sesiones de primer plano y sus esperas no inactivas; no incluye procesos de fondo ni esperas Idle.

**S13.** El usuario SYS inserta en la tabla HR.T y recibe ORA-01950 sobre el tablespace USERS. ¿Quién necesita
cuota?
- **A.** SYS
- **B.** HR
- **C.** SYSTEM
- **D.** Nadie: SYS tiene UNLIMITED TABLESPACE
**Respuesta: B.** La cuota corresponde al propietario de la tabla y del segmento que debe crecer, HR.

**S14.** ¿Sobre qué dos tipos de tablespace no se puede conceder cuota (ORA-30041)? (Elige dos.)
- **A.** Undo
- **B.** SYSAUX
- **C.** Temporal
- **D.** Bigfile
- **E.** De solo lectura
**Respuesta: A y C.** No se conceden cuotas sobre tablespaces de undo ni temporales.

**S15.** Una sesión con RESUMABLE habilitado se queda sin cuota. ¿Qué dos afirmaciones son ciertas? (Elige dos.)
- **A.** La sentencia se suspende hasta el timeout.
- **B.** La sentencia se deshace inmediatamente.
- **C.** La suspensión se ve en DBA_RESUMABLE.
- **D.** Oracle amplía la cuota automáticamente.
- **E.** La sesión se desconecta.
**Respuesta: A y C.** Con RESUMABLE la sentencia puede quedar suspendida hasta el timeout y su estado se consulta en DBA_RESUMABLE.

**S16.** ¿Qué requisito previo tiene ALTER TABLE t SHRINK SPACE?
- **A.** Que la tabla esté en un tablespace bigfile.
- **B.** ENABLE ROW MOVEMENT y ASSM.
- **C.** Que la tabla no tenga índices.
- **D.** Que la base esté en NOARCHIVELOG.
**Respuesta: B.** SHRINK SPACE requiere gestión automática de segmentos (ASSM) y que la tabla permita mover filas.

**S17.** Un perfil tiene FAILED_LOGIN_ATTEMPTS 3 y PASSWORD_LOCK_TIME 1. Tras tres fallos, ¿qué estado
muestra DBA_USERS?
- **A.** LOCKED
- **B.** LOCKED(TIMED)
- **C.** EXPIRED
- **D.** EXPIRED(GRACE)
**Respuesta: B.** Al superar los intentos fallidos permitidos, la cuenta queda bloqueada temporalmente según PASSWORD_LOCK_TIME.

**S18.** A concedió a B un privilegio de sistema que había recibido WITH ADMIN OPTION. El DBA lo revoca a A.
¿Qué pasa con B?
- **A.** Lo pierde en cascada.
- **B.** Lo conserva.
- **C.** Lo pierde solo si A era su creador.
- **D.** Queda pendiente de confirmación.
**Respuesta: B.** La revocación de un privilegio de sistema a A no se propaga a los usuarios a quienes A lo concedió con ADMIN OPTION.

**S19.** ¿Qué dos acciones dejan un índice en estado UNUSABLE? (Elige dos.)
- **A.** ALTER TABLE ... MOVE sin UPDATE INDEXES
- **B.** ALTER INDEX ... UNUSABLE
- **C.** ALTER TABLE ... ADD columna
- **D.** GATHER_TABLE_STATS
- **E.** ALTER INDEX ... REBUILD ONLINE
**Respuesta: A y B.** Un MOVE sin actualizar los índices puede dejarlos UNUSABLE, y ALTER INDEX ... UNUSABLE lo hace explícitamente.

**S20.** ¿Qué procedimiento activa la traza de la sesión de otro usuario indicando su SID y SERIAL#?
- **A.** DBMS_SESSION.SET_SQL_TRACE
- **B.** DBMS_MONITOR.SESSION_TRACE_ENABLE
- **C.** DBMS_SYSTEM.KSDWRT
- **D.** ALTER SESSION SET SQL_TRACE
**Respuesta: B.** DBMS_MONITOR.SESSION_TRACE_ENABLE activa la traza de otra sesión identificada por SID y SERIAL#.

**S21.** ¿Qué parámetro fija la raíz del ADR?
- **A.** BACKGROUND_DUMP_DEST
- **B.** USER_DUMP_DEST
- **C.** DIAGNOSTIC_DEST
- **D.** AUDIT_FILE_DEST
**Respuesta: C.** DIAGNOSTIC_DEST establece la raíz del Automatic Diagnostic Repository (ADR).

**S22.** En la guardia, una sesión espera en «enq: TX - row lock contention». ¿Cuál es el primer paso correcto?
- **A.** Reiniciar la instancia.
- **B.** Terminar la sesión que espera.
- **C.** Identificar al bloqueador (BLOCKING_SESSION) y qué está haciendo.
- **D.** Aumentar UNDO_RETENTION.
**Respuesta: C.** Primero hay que identificar la sesión bloqueadora y entender su actividad antes de intervenir sobre cualquiera de las sesiones.
