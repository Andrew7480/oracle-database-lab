-- database/migrations/V000__setup_entornos_negocio.sql
WHENEVER SQLERROR EXIT SQL.SQLCODE
alter session set container = freepdb1;
-- Entorno 1: Academia
create tablespace tbs_academia
   datafile 'academia01.dbf' size 100M
   autoextend on next 50M;
create user admin_academia identified by "Academia_2026_*"
   default tablespace tbs_academia
   quota unlimited on tbs_academia;
grant db_developer_role,
   create session
to admin_academia;
-- Entorno 2: Clinica
create tablespace tbs_clinica
   datafile 'clinica01.dbf' size 100M
   autoextend on next 50M;
create user admin_clinica identified by "Clinica_2026_*"
   default tablespace tbs_clinica
   quota unlimited on tbs_clinica;
grant db_developer_role,
   create session
to admin_clinica;
-- Entorno 3: Retail
create tablespace tbs_retail
   datafile 'retail01.dbf' size 100M
   autoextend on next 50M;
create user admin_retail identified by "Retail_2026_*"
   default tablespace tbs_retail
   quota unlimited on tbs_retail;
grant db_developer_role,
   create session
to admin_retail;
-- Entorno 4: Logistica
create tablespace tbs_logistica
   datafile 'logistica01.dbf' size 100M
   autoextend on next 50M;
create user admin_logistica identified by "Logistica_2026_*"
   default tablespace tbs_logistica
   quota unlimited on tbs_logistica;
grant db_developer_role,
   create session
to admin_logistica;
-- Entorno 5: Fintech
create tablespace tbs_fintech
   datafile 'fintech01.dbf' size 100M
   autoextend on next 50M;
create user admin_fintech identified by "Fintech_2026_*"
   default tablespace tbs_fintech
   quota unlimited on tbs_fintech;
grant db_developer_role,
   create session
to admin_fintech;
pro    == Verificacion: usuarios de negocio ==
select username,
       default_tablespace,
       account_status
  from dba_users
 where username like 'ADMIN\_%' escape '\'
 order by username;
EXIT