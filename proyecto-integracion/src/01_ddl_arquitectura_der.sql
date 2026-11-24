/* ============================================================================
   01_DDL_ARQUITECTURA_DER.SQL
   Casa de Cambio — Arquitectura Medallón en SQL Server
   Crea la base de datos, los 3 esquemas (bronce, plata, oro) y todas las
   tablas del modelo, con sus llaves primarias, foráneas y restricciones.
   ============================================================================ */

-- CREATE DATABASE CasaDeCambio;
-- GO
-- USE CasaDeCambio;
-- GO

/* ============================================================================
   ESQUEMAS DE LA ARQUITECTURA MEDALLÓN
   bronce = ingesta cruda (tal cual llega de las fuentes)
   plata  = datos limpios, validados e íntegros (el modelo relacional)
   oro    = vistas y procedimientos de consumo para negocio / BI
   ============================================================================ */
IF SCHEMA_ID('bronce') IS NULL EXEC('CREATE SCHEMA bronce');
GO
IF SCHEMA_ID('plata') IS NULL EXEC('CREATE SCHEMA plata');
GO
IF SCHEMA_ID('oro') IS NULL EXEC('CREATE SCHEMA oro');
GO

-- Borrado en orden inverso a las dependencias (para poder re-ejecutar el script)
IF OBJECT_ID('oro.sp_HistorialClientePorFechas', 'P') IS NOT NULL DROP PROCEDURE oro.sp_HistorialClientePorFechas;
IF OBJECT_ID('oro.sp_ConsultarOperacionPorID',   'P') IS NOT NULL DROP PROCEDURE oro.sp_ConsultarOperacionPorID;
IF OBJECT_ID('oro.sp_InsertarOperacion',         'P') IS NOT NULL DROP PROCEDURE oro.sp_InsertarOperacion;
IF OBJECT_ID('oro.vw_ResumenKPIDivisa',    'V') IS NOT NULL DROP VIEW oro.vw_ResumenKPIDivisa;
IF OBJECT_ID('oro.vw_Clientes360',         'V') IS NOT NULL DROP VIEW oro.vw_Clientes360;
IF OBJECT_ID('oro.vw_OperacionesDetalle',  'V') IS NOT NULL DROP VIEW oro.vw_OperacionesDetalle;
IF OBJECT_ID('plata.Rechazos',    'U') IS NOT NULL DROP TABLE plata.Rechazos;
IF OBJECT_ID('plata.Operaciones', 'U') IS NOT NULL DROP TABLE plata.Operaciones;
IF OBJECT_ID('plata.TiposCambio', 'U') IS NOT NULL DROP TABLE plata.TiposCambio;
IF OBJECT_ID('plata.Divisas',     'U') IS NOT NULL DROP TABLE plata.Divisas;
IF OBJECT_ID('plata.Empleados',   'U') IS NOT NULL DROP TABLE plata.Empleados;
IF OBJECT_ID('plata.Clientes',    'U') IS NOT NULL DROP TABLE plata.Clientes;
IF OBJECT_ID('bronce.Stg_Clientes',       'U') IS NOT NULL DROP TABLE bronce.Stg_Clientes;
IF OBJECT_ID('bronce.Stg_TiposCambio_API','U') IS NOT NULL DROP TABLE bronce.Stg_TiposCambio_API;
IF OBJECT_ID('bronce.Stg_Operaciones',    'U') IS NOT NULL DROP TABLE bronce.Stg_Operaciones;
GO

/* ============================================================================
   ESQUEMA PLATA — modelo relacional limpio
   ============================================================================ */

CREATE TABLE plata.Clientes (
    id_cliente   INT          NOT NULL,
    nombre       VARCHAR(50)  NULL,
    telefono     VARCHAR(15)  NULL,
    CONSTRAINT PK_Clientes PRIMARY KEY (id_cliente)
);

CREATE TABLE plata.Empleados (
    id_empleado  INT          NOT NULL,
    nombre       VARCHAR(50)  NULL,
    puesto       VARCHAR(30)  NULL,
    CONSTRAINT PK_Empleados PRIMARY KEY (id_empleado)
);

CREATE TABLE plata.Divisas (
    id_divisa    INT          NOT NULL,
    nombre       VARCHAR(30)  NULL,
    codigo       VARCHAR(5)   NULL,
    CONSTRAINT PK_Divisas PRIMARY KEY (id_divisa)
);

CREATE TABLE plata.TiposCambio (
    id_tipo      INT            NOT NULL,
    id_divisa    INT            NOT NULL,
    compra       DECIMAL(10,2)  NULL,
    venta        DECIMAL(10,2)  NULL,
    fecha        DATE           NULL,
    CONSTRAINT PK_TiposCambio PRIMARY KEY (id_tipo),
    CONSTRAINT FK_TiposCambio_Divisas FOREIGN KEY (id_divisa)
        REFERENCES plata.Divisas (id_divisa)
);

CREATE TABLE plata.Operaciones (
    id_operacion    INT            NOT NULL,
    id_cliente      INT            NOT NULL,
    id_empleado     INT            NOT NULL,
    id_divisa       INT            NOT NULL,
    id_tipo         INT            NOT NULL,
    tipo_operacion  VARCHAR(20)    NULL,
    cantidad        DECIMAL(10,2)  NULL,
    total_mxn       DECIMAL(10,2)  NULL,
    fecha           DATE           NULL,
    CONSTRAINT PK_Operaciones PRIMARY KEY (id_operacion),
    CONSTRAINT FK_Operaciones_Clientes    FOREIGN KEY (id_cliente)  REFERENCES plata.Clientes (id_cliente),
    CONSTRAINT FK_Operaciones_Empleados   FOREIGN KEY (id_empleado) REFERENCES plata.Empleados (id_empleado),
    CONSTRAINT FK_Operaciones_Divisas     FOREIGN KEY (id_divisa)   REFERENCES plata.Divisas (id_divisa),
    CONSTRAINT FK_Operaciones_TiposCambio FOREIGN KEY (id_tipo)     REFERENCES plata.TiposCambio (id_tipo),
    CONSTRAINT CK_Operaciones_Tipo     CHECK (tipo_operacion IN ('Compra', 'Venta')),
    CONSTRAINT CK_Operaciones_Cantidad CHECK (cantidad > 0)
);
GO

-- Bitácora de registros rechazados durante la limpieza (resultado del proceso plata)
CREATE TABLE plata.Rechazos (
    origen   VARCHAR(30),
    folio    VARCHAR(10),
    motivo   VARCHAR(100)
);
GO

/* ============================================================================
   ESQUEMA BRONCE — espejo de ingesta cruda (tal cual llega de cada fuente)
   Sin llave primaria: deben poder recibir duplicados y errores tal como llegan.
   ============================================================================ */

-- Origen 1: operaciones exportadas del sistema de caja
CREATE TABLE bronce.Stg_Operaciones (
    folio           VARCHAR(10),
    fecha_hora      DATETIME,
    clave_cliente   VARCHAR(10),
    id_empleado     INT,
    codigo_divisa   VARCHAR(5),
    tipo_operacion  VARCHAR(20),
    cantidad        DECIMAL(10,2)
);

-- Origen 2: tipos de cambio oficiales (API externa / Banxico)
CREATE TABLE bronce.Stg_TiposCambio_API (
    fecha_consulta        DATE,
    par_divisas           VARCHAR(10),
    tasa_oficial_banxico  DECIMAL(10,4),
    spread_mercado_pct    DECIMAL(5,2)
);

-- Origen 3: clientes nuevos capturados en el CRM
CREATE TABLE bronce.Stg_Clientes (
    clave_cliente  VARCHAR(10),
    nombre         VARCHAR(60),
    telefono       VARCHAR(20)
);
GO
