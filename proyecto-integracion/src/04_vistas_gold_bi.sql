/* ============================================================================
   04_VISTAS_GOLD_BI.SQL
   Casa de Cambio — Capa ORO: vistas analíticas y procedimientos de consumo
   Construidas sobre PLATA, siempre reflejan los datos ya limpios e integrados.
   ============================================================================ */

/* ============================================================================
   VISTA 1 — Operativa: detalle de cada operación
   ============================================================================ */
CREATE VIEW oro.vw_OperacionesDetalle AS
SELECT
    o.id_operacion,
    o.fecha,
    o.id_cliente,
    c.nombre      AS cliente,
    e.nombre      AS empleado,
    d.codigo      AS divisa,
    o.tipo_operacion,
    o.cantidad,
    CASE o.tipo_operacion WHEN 'Compra' THEN t.compra ELSE t.venta END AS tasa_aplicada,
    o.total_mxn
FROM plata.Operaciones o
JOIN plata.Clientes    c ON c.id_cliente  = o.id_cliente
JOIN plata.Empleados   e ON e.id_empleado = o.id_empleado
JOIN plata.Divisas     d ON d.id_divisa   = o.id_divisa
JOIN plata.TiposCambio t ON t.id_tipo     = o.id_tipo;
GO

/* ============================================================================
   VISTA 2 — Analítica 360°: comportamiento de cada cliente
   ============================================================================ */
CREATE VIEW oro.vw_Clientes360 AS
SELECT
    c.id_cliente,
    c.nombre,
    c.telefono,
    COUNT(o.id_operacion)                                               AS num_operaciones,
    SUM(CASE WHEN o.tipo_operacion = 'Compra' THEN 1 ELSE 0 END)        AS num_compras,
    SUM(CASE WHEN o.tipo_operacion = 'Venta'  THEN 1 ELSE 0 END)        AS num_ventas,
    ISNULL(SUM(CASE WHEN o.tipo_operacion = 'Compra' THEN o.total_mxn END), 0) AS mxn_recibidos_por_cliente,
    ISNULL(SUM(CASE WHEN o.tipo_operacion = 'Venta'  THEN o.total_mxn END), 0) AS mxn_pagados_por_cliente,
    MIN(o.fecha)                                                        AS primera_operacion,
    MAX(o.fecha)                                                        AS ultima_operacion
FROM plata.Clientes c
LEFT JOIN plata.Operaciones o ON o.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre, c.telefono;
GO

/* ============================================================================
   VISTA 3 — Resumen KPI: indicadores por divisa
   ============================================================================ */
CREATE VIEW oro.vw_ResumenKPIDivisa AS
SELECT
    d.codigo                                                            AS divisa,
    d.nombre,
    COUNT(o.id_operacion)                                               AS num_operaciones,
    ISNULL(SUM(CASE WHEN o.tipo_operacion = 'Compra' THEN o.cantidad END), 0) AS cantidad_comprada,
    ISNULL(SUM(CASE WHEN o.tipo_operacion = 'Venta'  THEN o.cantidad END), 0) AS cantidad_vendida,
    ISNULL(SUM(CASE WHEN o.tipo_operacion = 'Compra' THEN o.total_mxn END), 0) AS mxn_pagados,
    ISNULL(SUM(CASE WHEN o.tipo_operacion = 'Venta'  THEN o.total_mxn END), 0) AS mxn_cobrados,
    ISNULL(SUM(o.total_mxn), 0)                                         AS monto_total_mxn,
    CAST(AVG(t.venta - t.compra) AS DECIMAL(10,2))                      AS spread_promedio
FROM plata.Divisas d
LEFT JOIN plata.Operaciones o ON o.id_divisa = d.id_divisa
LEFT JOIN plata.TiposCambio t ON t.id_tipo   = o.id_tipo
GROUP BY d.codigo, d.nombre;
GO

/* ============================================================================
   PROCEDIMIENTO 1 — Inserción controlada con validación
   ============================================================================ */
CREATE PROCEDURE oro.sp_InsertarOperacion
    @id_cliente      INT,
    @id_empleado     INT,
    @codigo_divisa   VARCHAR(5),
    @tipo_operacion  VARCHAR(20),
    @cantidad        DECIMAL(10,2),
    @fecha           DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_divisa INT, @id_tipo INT, @tasa DECIMAL(10,2), @id_operacion INT;

    SET @codigo_divisa  = UPPER(LTRIM(RTRIM(@codigo_divisa)));
    SET @tipo_operacion = UPPER(LEFT(LTRIM(RTRIM(@tipo_operacion)), 1))
                        + LOWER(SUBSTRING(LTRIM(RTRIM(@tipo_operacion)), 2, 20));

    IF NOT EXISTS (SELECT 1 FROM plata.Clientes WHERE id_cliente = @id_cliente)
        THROW 50001, 'El cliente no existe.', 1;
    IF NOT EXISTS (SELECT 1 FROM plata.Empleados WHERE id_empleado = @id_empleado)
        THROW 50002, 'El empleado no existe.', 1;
    IF @tipo_operacion NOT IN ('Compra', 'Venta')
        THROW 50003, 'El tipo de operación debe ser Compra o Venta.', 1;
    IF @cantidad IS NULL OR @cantidad <= 0
        THROW 50004, 'La cantidad debe ser mayor a cero.', 1;

    SELECT @id_divisa = id_divisa FROM plata.Divisas WHERE codigo = @codigo_divisa;
    IF @id_divisa IS NULL
        THROW 50005, 'La divisa no está en el catálogo.', 1;

    SELECT @id_tipo = id_tipo,
           @tasa    = CASE @tipo_operacion WHEN 'Compra' THEN compra ELSE venta END
    FROM plata.TiposCambio
    WHERE id_divisa = @id_divisa AND fecha = @fecha;
    IF @id_tipo IS NULL
        THROW 50006, 'No hay tipo de cambio registrado para esa divisa y fecha.', 1;

    BEGIN TRANSACTION;
        SELECT @id_operacion = ISNULL(MAX(id_operacion), 0) + 1
        FROM plata.Operaciones WITH (UPDLOCK, HOLDLOCK);

        INSERT INTO plata.Operaciones (id_operacion, id_cliente, id_empleado, id_divisa, id_tipo,
                                       tipo_operacion, cantidad, total_mxn, fecha)
        VALUES (@id_operacion, @id_cliente, @id_empleado, @id_divisa, @id_tipo,
                @tipo_operacion, @cantidad, ROUND(@cantidad * @tasa, 2), @fecha);
    COMMIT TRANSACTION;

    SELECT * FROM oro.vw_OperacionesDetalle WHERE id_operacion = @id_operacion;
END;
GO

/* ============================================================================
   PROCEDIMIENTO 2 — Consulta de una operación por ID
   ============================================================================ */
CREATE PROCEDURE oro.sp_ConsultarOperacionPorID
    @id_operacion INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM plata.Operaciones WHERE id_operacion = @id_operacion)
        THROW 50010, 'La operación no existe.', 1;

    SELECT * FROM oro.vw_OperacionesDetalle WHERE id_operacion = @id_operacion;
END;
GO

/* ============================================================================
   PROCEDIMIENTO 3 — Historial de un cliente por fechas
   ============================================================================ */
CREATE PROCEDURE oro.sp_HistorialClientePorFechas
    @id_cliente   INT,
    @FechaInicio  DATE,
    @FechaFin     DATE
AS
BEGIN
    SET NOCOUNT ON;
    IF @FechaInicio > @FechaFin
        THROW 50020, 'La fecha inicial no puede ser mayor que la final.', 1;

    SELECT id_operacion, fecha, divisa, tipo_operacion, cantidad, tasa_aplicada, total_mxn, empleado
    FROM oro.vw_OperacionesDetalle
    WHERE id_cliente = @id_cliente
      AND fecha BETWEEN @FechaInicio AND @FechaFin
    ORDER BY fecha, id_operacion;
END;
GO

/* ============================================================================
   EJEMPLOS DE USO
   ============================================================================ */
EXEC oro.sp_InsertarOperacion @id_cliente = 2, @id_empleado = 3, @codigo_divisa = 'usd',
                              @tipo_operacion = 'compra', @cantidad = 400, @fecha = '2026-08-06';
EXEC oro.sp_ConsultarOperacionPorID @id_operacion = 21;
EXEC oro.sp_HistorialClientePorFechas @id_cliente = 1, @FechaInicio = '2026-08-01', @FechaFin = '2026-08-06';
SELECT * FROM oro.vw_Clientes360 ORDER BY num_operaciones DESC;
SELECT * FROM oro.vw_ResumenKPIDivisa ORDER BY monto_total_mxn DESC;
GO
