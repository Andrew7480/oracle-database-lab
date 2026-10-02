-- scripts/deployment/env/12-ords-habilitar-alumno.sql
-- Requiere que app_pwd se defina ANTES de ejecutarlo. La contraseña nunca se escribe aquí.
   SET VERIFY OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
alter session set container = freepdb1;
declare
   v_existe number;
begin
   select count(*)
     into v_existe
     from dba_users
    where username = 'ALUMNO';
   if v_existe = 0 then
      execute immediate 'CREATE USER alumno IDENTIFIED BY "&&app_pwd" ' || 'DEFAULT TABLESPACE USERS QUOTA 100M ON USERS';
      execute immediate 'GRANT DB_DEVELOPER_ROLE, CREATE SESSION TO alumno';
   end if;
end;
/
begin
   ords_admin.enable_schema(
      p_enabled             => true,
      p_schema              => 'ALUMNO',
      p_url_mapping_type    => 'BASE_PATH',
      p_url_mapping_pattern => 'alumno',
      p_auto_rest_auth      => true
   );
   commit;
end;
/
pro    == Verificacion: usuario de Database Actions ==
select username,
       account_status,
       default_tablespace
  from dba_users
 where username = 'ALUMNO';
EXIT