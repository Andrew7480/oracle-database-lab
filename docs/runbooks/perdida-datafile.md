# Runbook — Pérdida de un datafile de aplicación

## Síntoma y alcance

Ante `ORA-01116`, `ORA-01110` y `ORA-27041`, identificar el datafile afectado. Si la PDB se cierra por el fallo de medio, también puede aparecer `ORA-63999`. En el simulacro, el archivo fue el datafile **16**, `FREEPDB1/academia01.dbf`.

## Comprobaciones previas

```sql
ARCHIVE LOG LIST;
SELECT name, open_mode FROM v$pdbs;
LIST BACKUP OF DATAFILE 16;
SELECT file#, name, status FROM v$datafile WHERE file# = 16;
```

Confirmar que la base está en `ARCHIVELOG`, que existe una copia RMAN y que el servicio afectado es un tablespace de aplicación, no `SYSTEM`. Avisar al DBA responsable y al dueño de la aplicación antes de iniciar la recuperación.

## Camino A: la PDB sigue abierta

```sql
ALTER DATABASE DATAFILE 16 OFFLINE;
```

Restaurar y recuperar con RMAN:

```rman
RESTORE DATAFILE 16;
RECOVER DATAFILE 16;
```

Después:

```sql
ALTER DATABASE DATAFILE 16 ONLINE;
```

## Camino B: aparece ORA-63999 y la PDB está montada

Mantener la PDB montada, restaurar y recuperar el datafile:

```rman
RESTORE DATAFILE 16;
RECOVER DATAFILE 16;
```

Abrir la PDB y comprobar el servicio:

```sql
ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;
SELECT name, open_mode FROM v$pdbs WHERE name = 'FREEPDB1';
SELECT estudiante_id, estado
FROM admin_academia.aca_estudiantes
WHERE estudiante_id = 104;
```

## Verificación y cierre

La PDB debe quedar `READ WRITE`, el datafile debe estar `ONLINE` y la fila de control debe conservar su valor confirmado. En el simulacro, la fila 104 quedó `EGRESADO`, el RPO fue **0** y el RTO fue **8 s** desde `OFFLINE` hasta `ONLINE` (**9 s** desde el fallo). Registrar hora, comandos, backup utilizado y resultado; avisar al DBA responsable y al dueño de la aplicación.
