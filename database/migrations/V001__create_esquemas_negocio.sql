-- database/migrations/V001__create_esquemas_negocio.sql
WHENEVER SQLERROR EXIT SQL.SQLCODE
alter session set container = freepdb1;
-- ===== Academia: integridad referencial =====
alter session set current_schema = admin_academia;
create table aca_estudiantes (
   estudiante_id       number generated always as identity primary key,
   dni                 varchar2(20)
      constraint uq_aca_dni unique
   not null,
   nombres             varchar2(100) not null,
   apellidos           varchar2(100) not null,
   email_institucional varchar2(150)
      constraint uq_aca_email unique
   not null,
   estado              varchar2(20) default 'ACTIVO'
      constraint chk_aca_estado check ( estado in ( 'ACTIVO',
                                                    'INACTIVO',
                                                    'EGRESADO',
                                                    'SUSPENDIDO' ) ),
   fecha_registro      timestamp default current_timestamp not null
);
create table aca_asignaturas (
   asignatura_id number generated always as identity primary key,
   codigo        varchar2(20)
      constraint uq_aca_codigo unique
   not null,
   nombre        varchar2(150) not null,
   creditos      number(2)
      constraint chk_aca_creditos check ( creditos > 0
         and creditos <= 10 )
);
create table aca_matriculas (
   matricula_id    number generated always as identity primary key,
   estudiante_id   number not null
      constraint fk_aca_mat_est
         references aca_estudiantes ( estudiante_id ),
   asignatura_id   number not null
      constraint fk_aca_mat_asi
         references aca_asignaturas ( asignatura_id ),
   periodo         varchar2(10) not null,
   fecha_matricula timestamp default current_timestamp not null,
   constraint uq_aca_matricula_unica unique ( estudiante_id,
                                              asignatura_id,
                                              periodo )
);
create index idx_aca_mat_est on
   aca_matriculas (
      estudiante_id
   );
create index idx_aca_mat_asi on
   aca_matriculas (
      asignatura_id
   );
-- ===== Clinica: datos sensibles (PII) =====
alter session set current_schema = admin_clinica;
create table cli_pacientes (
   paciente_id                number generated always as identity primary key,
   numero_seguro              varchar2(50)
      constraint uq_cli_seguro unique
   not null,
   nombre_completo            varchar2(200) not null,
   fecha_nacimiento           date not null,
   telefono_contacto          varchar2(20),
   datos_sensibles_enmascarar varchar2(4000)
);
create table cli_medicos (
   medico_id        number generated always as identity primary key,
   licencia_medica  varchar2(50)
      constraint uq_cli_licencia unique
   not null,
   especialidad     varchar2(100) not null,
   estado_operativo varchar2(20) default 'DISPONIBLE'
      constraint chk_cli_estado check ( estado_operativo in ( 'DISPONIBLE',
                                                              'CIRUGIA',
                                                              'VACACIONES',
                                                              'INACTIVO' ) )
);
create table cli_citas (
   cita_id         number generated always as identity primary key,
   paciente_id     number not null
      constraint fk_cli_cita_pac
         references cli_pacientes ( paciente_id ),
   medico_id       number not null
      constraint fk_cli_cita_med
         references cli_medicos ( medico_id ),
   fecha_hora_cita timestamp not null,
   motivo          varchar2(500),
   estado          varchar2(20) default 'PROGRAMADA'
      constraint chk_cli_estado_cita check ( estado in ( 'PROGRAMADA',
                                                         'COMPLETADA',
                                                         'CANCELADA',
                                                         'NO_ASISTE' ) ),
   creado_el       timestamp default current_timestamp,
   constraint uq_cli_horario_medico unique ( medico_id,
                                             fecha_hora_cita )
);
create index idx_cli_citas_paciente on
   cli_citas (
      paciente_id
   );
create index idx_cli_citas_fecha on
   cli_citas (
      fecha_hora_cita
   );
-- ===== Retail: alto volumen OLTP =====
alter session set current_schema = admin_retail;
create table ret_productos (
   producto_id  number generated always as identity primary key,
   sku          varchar2(50)
      constraint uq_ret_sku unique
   not null,
   nombre       varchar2(200) not null,
   precio_base  number(10,2)
      constraint chk_ret_precio check ( precio_base >= 0 )
   not null,
   stock_actual number(8) default 0
      constraint chk_ret_stock check ( stock_actual >= 0 )
   not null
);
create table ret_ventas_cabecera (
   venta_id          number generated always as identity primary key,
   fecha_transaccion timestamp default current_timestamp not null,
   caja_id           number not null,
   metodo_pago       varchar2(20)
      constraint chk_ret_pago check ( metodo_pago in ( 'EFECTIVO',
                                                       'TARJETA',
                                                       'QR',
                                                       'TRANSFERENCIA' ) ),
   total_venta       number(12,2) default 0 not null
);
create table ret_ventas_detalle (
   detalle_id      number generated always as identity primary key,
   venta_id        number not null
      constraint fk_ret_det_ven
         references ret_ventas_cabecera ( venta_id )
            on delete cascade,
   producto_id     number not null
      constraint fk_ret_det_prod
         references ret_productos ( producto_id ),
   cantidad        number(6)
      constraint chk_ret_cantidad check ( cantidad > 0 )
   not null,
   precio_unitario number(10,2) not null,
   subtotal        number(12,2) generated always as ( cantidad * precio_unitario ) virtual
);
create index idx_ret_ventas_fecha on
   ret_ventas_cabecera (
      fecha_transaccion
   );
create index idx_ret_detalle_venta on
   ret_ventas_detalle (
      venta_id
   );
create index idx_ret_detalle_prod on
   ret_ventas_detalle (
      producto_id
   );
-- ===== Logistica: trazabilidad y estados concurrentes =====
alter session set current_schema = admin_logistica;
create table log_almacenes (
   almacen_id       number generated always as identity primary key,
   codigo_iata      varchar2(3)
      constraint uq_log_iata unique
   not null,
   ciudad           varchar2(100) not null,
   capacidad_maxima number not null
);
create table log_envios (
   envio_id             number generated always as identity primary key,
   tracking_number      varchar2(100)
      constraint uq_log_tracking unique
   not null,
   almacen_origen       number not null
      constraint fk_log_env_ori
         references log_almacenes ( almacen_id ),
   almacen_destino      number not null
      constraint fk_log_env_des
         references log_almacenes ( almacen_id ),
   peso_kg              number(6,2) not null,
   estado_actual        varchar2(30) default 'EN_PREPARACION'
      constraint chk_log_estado check ( estado_actual in ( 'EN_PREPARACION',
                                                           'EN_TRANSITO',
                                                           'EN_ADUANA',
                                                           'ENTREGADO',
                                                           'EXTRAVIADO' ) ),
   ultima_actualizacion timestamp default current_timestamp not null
);
create table log_eventos_tracking (
   evento_id         number generated always as identity primary key,
   envio_id          number not null
      constraint fk_log_evt_env
         references log_envios ( envio_id ),
   estado_registrado varchar2(30) not null,
   fecha_evento      timestamp default current_timestamp not null,
   observaciones     varchar2(500)
);
create index idx_log_eventos_envio on
   log_eventos_tracking (
      envio_id
   );
-- ===== Fintech: ACID y precision numerica =====
alter session set current_schema = admin_fintech;
create table fin_cuentas (
   cuenta_id     number generated always as identity primary key,
   numero_cuenta varchar2(20)
      constraint uq_fin_numero unique
   not null,
   tipo_moneda   varchar2(3) default 'USD' not null,
   saldo         number(18,4) default 0 not null,
   estado        varchar2(15) default 'ACTIVA'
      constraint chk_fin_estado check ( estado in ( 'ACTIVA',
                                                    'CONGELADA',
                                                    'CERRADA' ) ),
   constraint chk_fin_saldo_positivo check ( saldo >= 0 )
      initially deferred deferrable
);
create table fin_transacciones (
   tx_id          number generated always as identity primary key,
   cuenta_origen  number
      constraint fk_fin_tx_ori
         references fin_cuentas ( cuenta_id ),
   cuenta_destino number
      constraint fk_fin_tx_des
         references fin_cuentas ( cuenta_id ),
   monto          number(18,4)
      constraint chk_fin_monto check ( monto > 0 )
   not null,
   tipo_operacion varchar2(20)
      constraint chk_fin_operacion check ( tipo_operacion in ( 'DEPOSITO',
                                                               'RETIRO',
                                                               'TRANSFERENCIA',
                                                               'COMISION' ) ),
   fecha_tx       timestamp default current_timestamp not null,
   hash_auditoria varchar2(256)
);
create index idx_fin_tx_origen on
   fin_transacciones (
      cuenta_origen
   );
create index idx_fin_tx_destino on
   fin_transacciones (
      cuenta_destino
   );
create index idx_fin_tx_fecha on
   fin_transacciones (
      fecha_tx
   );
pro    == Verificacion: tablas por esquema ==
select owner,
       count(*) as tablas
  from dba_tables
 where owner like 'ADMIN\_%' escape '\'
 group by owner
 order by owner;
EXIT