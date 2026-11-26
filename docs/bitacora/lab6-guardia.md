# Bitácora de Guardia Nocturna — Lab 6 (E008)

Registro técnico de incidentes atendidos durante el turno de guardia sobre FREE / FREEPDB1.

---

## INC-601 — Bloqueo de fila en ficha de alumno (Secretaría)

### 1. Síntoma reportado
La usuaria ANA_GARCIA reporta a las 23:49 que la aplicación se queda congelada al intentar guardar cambios en la ficha del alumno 101 en FREEPDB1. Reiniciar su ordenador cliente dos veces no resolvió el problema.

### 2. Evidencia recopilada (antes de intervenir)
Evidencia = [Evidencia](/docs/bitacora/lab6/evidencia/script/20261125T234950Z_08-inc1-turno.script.log)

Aquí comparamos con nuestra bitácora que el turno anterior al incidente ha cambiado:

Comprobamos que la infraestructura general está sana: la instancia FREE está abierta con logins ALLOWED, la PDB FREEPDB1 está disponible en READ WRITE, ningún tablespace supera el 85 % y no hay alertas pendientes.

Sin embargo, detectamos que SESIONES_BLOQUEADAS = 1, cuando antes no había ninguna. Esto descarta una caída de la base o falta de espacio y confirma la hipótesis de que la sesión de ANA_GARCIA en FREEPDB1 está detenida esperando a que se libere un bloqueo.

### 3. Preservar la evidencia

Capturar el contexto = [Diagnostico](/docs/bitacora/lab6/evidencia/script/20261125T234952Z_08-inc1-diagnostico-antes.script.log)

La sesión de ANA_GARCIA se encuentra bloqueada desde hace 7 segundos porque está intentando modificar un registro de la tabla ACA_ESTUDIANTES que actualmente está retenido por otra sesión. El bloqueo afecta exactamente al archivo 1024, bloque 781 y fila 5.

El problema se origina en la sesión SID 68 (SERIAL# 42887), correspondiente a APP_ACADEMIA, que estaba ejecutando el módulo matriculas, en la acción cierre-periodo. Esta sesión mantiene un bloqueo exclusivo de transacción (TX con LMODE = 6 y BLOCK = 1) sobre el registro que SID 57 solicita (REQUEST = 6), aunque lleva 11 segundos inactiva, esperando en PL/SQL lock timer (clase Idle). Es decir, aunque no está realizando ninguna operación activa en ese momento, sigue reteniendo el bloqueo sin hacer COMMIT ni ROLLBACK e impidiendo que la otra sesión pueda continuar.

También podemos observar en V$TRANSACTION que la transacción tiene muy pocos cambios pendientes de deshacer (USED_UBLK = 1 y USED_UREC = 1) y permanece abierta desde las 23:49:42, por lo que el impacto de un rollback al terminar esa sesión sería mínimo. Con la práctica definimos que antes de terminar una sesión conviene revisar V$TRANSACTION: si lleva mucho tiempo trabajando sin confirmar, el rollback también tardará y habría que valorar si contactar primero con el responsable del proceso.

En resumen, la sesión de ANA_GARCIA está esperando porque la sesión de APP_ACADEMIA mantiene un bloqueo exclusivo sobre una fila de ACA_ESTUDIANTES sin realizar actividad, lo que explica que la pantalla de secretaría se quede colgada.

### 4. Formular hipótesis

La causa confirmada con la evidencia es que la sesión 68 de APP_ACADEMIA modificó la fila del alumno 101 en ACA_ESTUDIANTES y dejó la transacción abierta sin confirmar (COMMIT), reteniendo un bloqueo exclusivo (TX, LMODE = 6) mientras espera inactiva. No hace falta consultar DBA_USERS porque ambas cuentas ya están conectadas dentro de la base (V$SESSION). Terminar únicamente la sesión bloqueadora (68,42887) forzará el rollback automático de su transacción (con coste mínimo de 1 bloque de undo) y liberará la fila para que ANA_GARCIA complete su operación.

### 5. Actuar con el menor cambio útil

Intervención = [Actuar](/docs/bitacora/lab6/evidencia/script/20261125T235030Z_08-inc1-actuar.script.log)

Se opta por terminar únicamente la sesión bloqueadora (SID 68, SERIAL# 42887) dentro de FREEPDB1 sin reiniciar la instancia ni afectar al resto de usuarios conectados:

    ALTER SESSION SET CONTAINER = FREEPDB1;
    ALTER SYSTEM KILL SESSION '68,42887' IMMEDIATE;

### 6. Validar el resultado

Diagnóstico posterior = [Diagnostico despues](/docs/bitacora/lab6/evidencia/script/20261125T235148Z_08-inc1-diagnostico-despues.script.log)
Validación alumno = [Validar alumno](/docs/bitacora/lab6/evidencia/script/20261125T235150Z_08-inc1-validar-alumno.script.log)

Al volver a ejecutar el diagnostico, las secciones 1, 2, 3 y 4 aparecen vacías, confirmando que ya no existe ningún bloqueo activo. Además, consultando directamente ADMIN_ACADEMIA.ACA_ESTUDIANTES en FREEPDB1 comprobamos que el estudiante 101 quedó guardado con estado ACTIVO.

### 7. Documentar y aprender

- Antes de matar una sesión bloqueadora, revisar siempre V$TRANSACTION (USED_UBLK y START_TIME) para estimar cuánto tardará el rollback y evitar sorpresas si la transacción lleva mucho trabajo acumulado.
- Como acción preventiva, revisar el código del proceso batch matriculas (acción cierre-periodo) para que confirme sus cambios (COMMIT) antes de entrar en esperas o pausas (PL/SQL lock timer) y configurar una alerta cuando enq: TX - row lock contention supere los 30 segundos.


## INC-602 — Problemas con conexión de instancias (Equipo de matrículas)

### 1. Síntoma reportado
El equipo de matrículas reporta que ninguna instancia de la aplicación conecta hace unos cuantos minutos. Nos pregunta si la base está caída ya que muestra el error ORA-12514.

### 2. Evidencia recopilada (antes de intervenir)
Evidencia = [Evidencia](/docs/bitacora/lab6/evidencia/script/20261126T002516Z_08-inc2-turno.script.log)

Primero, desde el mismo error ORA-12514 nos podemos dar una idea de lo que pasa: ocurre cuando el listener de Oracle está activo, pero no tiene registrado el servicio solicitado en la cadena de conexión. Al revisar el estado general del turno confirmamos que la base no está caída: la instancia FREE está abierta (OPEN, logins ALLOWED) y la PDB FREEPDB1 está disponibles.

### 3. Preservar la evidencia

Capturar el contexto = [Diagnostico](/docs/bitacora/lab6/evidencia/script/20261126T002521Z_08-inc2-diagnostico-antes.script.log)

En el diagnóstico detallado notamos en la sección 6 cómo el servicio academia_app dentro de FREEPDB1 (CON_ID = 3) aparece no arrancado (ARRANCADO = NO), mientras que el servicio base FREEPDB1 sí está arrancado. Esta es la razón por la cual no está registrado en el listener. Aquí se aprecia la buena práctica de usar servicios dedicados por aplicación: con un servicio propio puedes parar, mover o medir solo a matrículas sin tocar a nadie más, y V$SESSION (columna SERVICE_NAME) te dice exactamente por qué servicio entró cada sesión.

### 4. Formular hipótesis

Nos vamos por el lado de que si arrancamos únicamente el servicio academia_app dentro de FREEPDB1, el proceso PMON/LREG de la instancia lo registrará automáticamente en el listener y todo volverá a funcionar sin necesidad de reiniciar la base de datos ni el listener. Como tarea posterior quedaría revisar el alert.log o los registros de mantenimiento para saber la causa de por qué se apagó.

### 5. Actuar con el menor cambio útil

Intervención = [Actuar](/docs/bitacora/lab6/evidencia/script/20261126T003447Z_08-inc2-actuar.script.log)

Entramos al contenedor FREEPDB1 y arrancamos únicamente el servicio detenido usando el paquete DBMS_SERVICE:

    ALTER SESSION SET CONTAINER = FREEPDB1;
    EXEC DBMS_SERVICE.START_SERVICE('academia_app');

### 6. Validar el resultado

Diagnóstico posterior = [Diagnostico despues](/docs/bitacora/lab6/evidencia/script/20261126T003510Z_08-inc2-diagnostico-despues.script.log)

Al volver a ejecutar el diagnostico verificamos que academia_app ya aparece con ARRANCADO = SI junto a FREEPDB1, confirmando que el servicio vuelve a estar levantado y anunciado por el listener.

### 7. Documentar y aprender

- Un error ORA-12514 no significa que la base de datos esté caída, sino que el servicio concreto que pide el cliente no está arrancado o registrado en el listener.
- Trabajar con servicios propios por aplicación (como academia_app) aísla fallos y facilita el diagnóstico por módulo en V$SESSION, pero conviene configurar su arranque automático al abrir la PDB (DBMS_SERVICE o trigger AFTER STARTUP) y revisar el alert.log para identificar qué detuvo el servicio.



## INC-603 — Cuenta de aplicación bloqueada / error ORA-28000 (Equipo de desarrollo / aplicación)

### 1. Síntoma reportado
Se reporta que las nuevas conexiones de la aplicación contra FREEPDB1 fallan al autenticarse con el usuario APP_ACADEMIA (error ORA-28000: the account is locked), mientras que las sesiones ya abiertas seguían operando.

### 2. Evidencia recopilada (antes de intervenir)
Evidencia = [Evidencia](/docs/bitacora/lab6/evidencia/script/20261126T004544Z_08-inc3-turno.script.log)

Comprobamos que toda la infraestructura está sana: la instancia FREE está OPEN con logins ALLOWED, la PDB FREEPDB1 está abierta en READ WRITE, ningún tablespace supera el 85 % y no existen bloqueos activos ni alertas del servidor pendientes. Esto descarta un fallo de disponibilidad y apunta a un problema específico de autenticación o estado de cuenta. Podemos inclinarnos con la informacion del ticket sobre el error ORA-28000.

### 3. Preservar la evidencia

Capturar el contexto = [Diagnostico](/docs/bitacora/lab6/evidencia/script/20261126T004548Z_08-inc3-diagnostico-antes.script.log)

En el diagnóstico detallado verificamos que no hay bloqueos y que todos los servicios de FREEPDB1 están arrancados. Sin embargo, aparece que la cuenta APP_ACADEMIA dentro de FREEPDB1 esta en estado LOCKED, asociada al perfil DEFAULT.

### 4. Formular hipótesis

El estado es LOCKED a secas y no LOCKED(TIMED), lo que indica que la cuenta APP_ACADEMIA no se bloqueó automáticamente por superar los 10 intentos fallidos de contraseña, sino que fue bloqueada de forma explícita/manual, probablemente por el script trimestral de bajas que se ejecuto en la tarde. Al estar bloqueada, cualquier nueva conexión de la aplicación recibe ORA-28000. La solución mínima y segura es desbloquear únicamente la cuenta APP_ACADEMIA en FREEPDB1 sin modificar su contraseña para no desconfigurar la aplicación.

### 5. Actuar con el menor cambio útil

Intervención = [Actuar](/docs/bitacora/lab6/evidencia/script/20261126T005035Z_08-inc3-actuar.script.log)

Entramos en el contenedor FREEPDB1 y desbloqueamos la cuenta de la aplicación mediante SQL:

    ALTER SESSION SET CONTAINER = FREEPDB1;
    ALTER USER app_academia ACCOUNT UNLOCK;

### 6. Validar el resultado

Diagnóstico posterior = [Diagnostico despues](/docs/bitacora/lab6/evidencia/script/20261126T005040Z_08-inc3-diagnostico-despues.script.log)

Al volver a ejecutarel diagnostico confirmamos que APP_ACADEMIA regresó a estado OPEN en FREEPDB1 y que el resto de servicios y sesiones siguen operando con normalidad.

### 7. Documentar y aprender

- Distinguir entre LOCKED y LOCKED(TIMED) en DBA_USERS ahorra mucho tiempo: LOCKED(TIMED) apunta a una aplicación con credenciales desactualizadas o fuerza bruta, mientras que LOCKED apunta a una acción administrativa manual o un script mal ejecutado.
- No cambiar la contraseña al desbloquear una cuenta de servicio salvo que exista evidencia de compromiso, ya que rompería todas las instancias de aplicación que usan esa credencial. Conviene revisar la auditoría unificada para identificar qué sesión ejecutó el bloqueo manual.


---

## Postmortems sin culpables

## INC-601 · Bloqueo de fila en ficha de alumno (Secretaría)
- Detección: 23:49 UTC · Ticket reportado por Ana García (Secretaría), indicando que la aplicación se quedaba congelada al guardar cambios en el alumno 101 en FREEPDB1.
- Impacto: Secretaría no pudo guardar modificaciones sobre la ficha del alumno 101 durante aproximadamente 1 minuto (desde las 23:49:42 hasta las 23:50:30 UTC).
- Diagnóstico: En turno.sql apareció SESIONES_BLOQUEADAS = 1; en 08-diagnostico.sql (V$SESSION, V$LOCK y V$TRANSACTION) se identificó la sesión SID 57 (ANA_GARCIA) esperando en enq: TX - row lock contention sobre ACA_ESTUDIANTES (archivo 1024, bloque 781, fila 5) por culpa de SID 68, SERIAL# 42887 (APP_ACADEMIA, módulo matriculas, acción cierre-periodo) con bloqueo TX LMODE = 6, BLOCK = 1 y USED_UBLK = 1.
- Causa raíz: El proceso batch de cierre de periodo ejecuta modificaciones sobre ACA_ESTUDIANTES y entra en espera inactiva (PL/SQL lock timer) sin haber confirmado previamente la transacción (COMMIT), reteniendo bloqueos exclusivos a nivel de fila.
- Intervención: ALTER SESSION SET CONTAINER = FREEPDB1; seguido de ALTER SYSTEM KILL SESSION '68,42887' IMMEDIATE; — era la acción más pequeña posible porque finaliza únicamente la sesión bloqueadora con un rollback mínimo (1 bloque de undo) sin reiniciar la PDB ni afectar al resto de usuarios.
- Validación: Ejecución de 08-diagnostico.sql (secciones 1 a 4 vacías, sin bloqueos activos) y consulta directa como consumidor sobre ADMIN_ACADEMIA.ACA_ESTUDIANTES WHERE estudiante_id = 101 confirmando estado ACTIVO.
- Acción preventiva: Modificar el procedimiento de cierre de periodo para emitir COMMIT antes de cualquier espera o pausa, y configurar una alerta automática cuando enq: TX - row lock contention supere los 30 segundos.

## INC-602 · Servicio de aplicación detenido / error ORA-12514 (Equipo de matrículas)
- Detección: 00:25 UTC · Aviso del equipo de matrículas reportando que ninguna instancia de la aplicación conectaba y devolvía ORA-12514.
- Impacto: Ninguna instancia de la aplicación de matrículas pudo establecer nuevas conexiones contra FREEPDB1 durante aproximadamente 10 minutos (hasta las 00:34:47 UTC).
- Diagnóstico: En turno.sql se confirmó que FREE (OPEN) y FREEPDB1 (READ WRITE) estaban operativas; en 08-diagnostico.sql (sección 6, CDB_SERVICES frente a V$ACTIVE_SERVICES) se detectó que en CON_ID = 3 el servicio academia_app figuraba con ARRANCADO = NO, por lo que no estaba publicado en el listener.
- Causa raíz: El servicio dedicado academia_app no tiene configurada la persistencia de estado ni arranque automático al abrir o mantener la PDB, por lo que tras detenerse quedó sin registro en el listener mientras la base seguía levantada.
- Intervención: ALTER SESSION SET CONTAINER = FREEPDB1; seguido de EXEC DBMS_SERVICE.START_SERVICE('academia_app'); — era la intervención mínima porque arranca exclusivamente el servicio afectado y fuerza su registro automático en el listener sin reiniciar la instancia ni el listener.
- Validación: Ejecución posterior de 08-diagnostico.sql (sección 6) verificando que academia_app pasó a ARRANCADO = SI junto a FREEPDB1, quedando anunciado por el listener para nuevas conexiones.
- Acción preventiva: Habilitar la persistencia del servicio academia_app (mediante DBMS_SERVICE.MODIFY_SERVICE o un trigger AFTER STARTUP en FREEPDB1) y añadir una comprobación periódica de servicios detenidos en la monitorización del turno.

## INC-603 · Cuenta de aplicación bloqueada / error ORA-28000 (Equipo de desarrollo / aplicación)
- Detección: 00:45 UTC · Reporte del equipo de desarrollo/aplicación indicando fallos ORA-28000 (the account is locked) en nuevas conexiones contra FREEPDB1 con APP_ACADEMIA.
- Impacto: Todas las nuevas conexiones de la aplicación con el usuario APP_ACADEMIA fueron rechazadas durante aproximadamente 5 minutos (de 00:45 a 00:50:35 UTC), manteniéndose operativas únicamente las sesiones ya establecidas.
- Diagnóstico: En 08-diagnostico.sql (sección 7, DBA_USERS) se detectó en CON_ID = 3 la cuenta APP_ACADEMIA con ACCOUNT_STATUS = LOCKED desde las 00:45 bajo el perfil DEFAULT, descartando bloqueo por intentos fallidos al no figurar como LOCKED(TIMED).
- Causa raíz: El proceso de mantenimiento/script trimestral de bajas no discrimina entre cuentas humanas y cuentas técnicas de servicio de aplicación, aplicando bloqueo administrativo (ACCOUNT LOCK) sobre APP_ACADEMIA.
- Intervención: ALTER SESSION SET CONTAINER = FREEPDB1; seguido de ALTER USER app_academia ACCOUNT UNLOCK; — era la intervención más pequeña y segura porque restaura el acceso inmediato de la cuenta sin alterar su contraseña ni invalidar la configuración de las aplicaciones clientes.
- Validación: Ejecución de 08-diagnostico.sql comprobando que la sección 7 (cuentas no abiertas) volvió a quedar vacía, confirmando que APP_ACADEMIA regresó a estado OPEN en FREEPDB1.
- Acción preventiva: Asignar un perfil dedicado (PROFILE) a las cuentas de aplicación y añadir una lista de exclusión explícita en los scripts de bajas periódicas para impedir que bloqueen usuarios de servicio.