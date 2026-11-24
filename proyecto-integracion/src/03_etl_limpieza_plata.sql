/* ============================================================================
   03_ETL_LIMPIEZA_PLATA.SQL
   Casa de Cambio — Protocolo de limpieza y calidad de datos
   Diagnostica, estandariza, deduplica, valida/rechaza e integra el lote de
   BRONCE hacia el modelo limpio en PLATA, dentro de una transacción.
   ============================================================================ */

/* ============================================================================
   FASE 1 — DIAGNÓSTICO (sobre BRONCE)
   ============================================================================ */

-- Folios repetidos en operaciones
SELECT folio, COUNT(*) AS veces
FROM bronce.Stg_Operaciones
GROUP BY folio
HAVING COUNT(*) > 1;

-- Valores distintos de tipo_operacion y codigo_divisa (espacios y mayúsculas)
SELECT DISTINCT tipo_operacion, LEN(tipo_operacion) AS longitud, DATALENGTH(tipo_operacion) AS bytes
FROM bronce.Stg_Operaciones;

SELECT DISTINCT codigo_divisa, DATALENGTH(codigo_divisa) AS bytes
FROM bronce.Stg_Operaciones;

-- Cantidades negativas o en cero
SELECT folio, cantidad
FROM bronce.Stg_Operaciones
WHERE cantidad <= 0;

-- Tipos de cambio con spread faltante y pares con formato distinto a 'XXX/MXN'
SELECT * FROM bronce.Stg_TiposCambio_API
WHERE spread_mercado_pct IS NULL
   OR par_divisas COLLATE Latin1_General_CS_AS NOT LIKE '[A-Z][A-Z][A-Z]/MXN';

-- Teléfonos con caracteres que no son dígitos y nombres con espacios de más
SELECT clave_cliente, nombre, telefono
FROM bronce.Stg_Clientes
WHERE telefono LIKE '%[^0-9]%'
   OR nombre LIKE ' %' OR nombre LIKE '% ' OR nombre LIKE '%  %';
GO

/* ============================================================================
   FASE 2 — ESTANDARIZACIÓN (sobre BRONCE)
   ============================================================================ */

-- Operaciones: quitar espacios, códigos en mayúsculas y tipo de operación con formato 'Compra'/'Venta'
UPDATE bronce.Stg_Operaciones
SET clave_cliente  = UPPER(LTRIM(RTRIM(clave_cliente))),
    codigo_divisa  = UPPER(LTRIM(RTRIM(codigo_divisa))),
    tipo_operacion = UPPER(LEFT(LTRIM(RTRIM(tipo_operacion)), 1))
                   + LOWER(SUBSTRING(LTRIM(RTRIM(tipo_operacion)), 2, 20));

-- Tipos de cambio: par en mayúsculas y sin espacios
UPDATE bronce.Stg_TiposCambio_API
SET par_divisas = UPPER(LTRIM(RTRIM(par_divisas)));

-- Clientes: clave en mayúsculas, nombre sin espacios dobles, teléfono solo con dígitos
UPDATE bronce.Stg_Clientes
SET clave_cliente = UPPER(LTRIM(RTRIM(clave_cliente))),
    nombre        = LTRIM(RTRIM(nombre)),
    telefono      = REPLACE(REPLACE(REPLACE(REPLACE(telefono, '(', ''), ')', ''), '-', ''), ' ', '');

WHILE EXISTS (SELECT 1 FROM bronce.Stg_Clientes WHERE nombre LIKE '%  %')
    UPDATE bronce.Stg_Clientes SET nombre = REPLACE(nombre, '  ', ' ') WHERE nombre LIKE '%  %';

-- Columnas calculadas que traducen el formato de origen al del modelo
ALTER TABLE bronce.Stg_Operaciones
    ADD fecha_operacion AS (CAST(fecha_hora AS DATE)),
        id_operacion    AS (CAST(SUBSTRING(folio, 4, 4) AS INT));        -- 'OP-0021' -> 21

ALTER TABLE bronce.Stg_TiposCambio_API
    ADD codigo_divisa AS (LEFT(par_divisas, 3));                         -- 'USD/MXN' -> 'USD'
GO

ALTER TABLE bronce.Stg_Operaciones ADD id_cliente AS (CAST(SUBSTRING(clave_cliente, 5, 6) AS INT));  -- 'CLI-011' -> 11
ALTER TABLE bronce.Stg_Clientes    ADD id_cliente AS (CAST(SUBSTRING(clave_cliente, 5, 6) AS INT));
GO

/* ============================================================================
   FASE 3 — DEDUPLICACIÓN (sobre BRONCE, vía ROW_NUMBER)
   ============================================================================ */

WITH Ops_Rank AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY folio ORDER BY fecha_hora DESC) AS rn
    FROM bronce.Stg_Operaciones
)
DELETE FROM Ops_Rank WHERE rn > 1;

WITH Tc_Rank AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY fecha_consulta, par_divisas ORDER BY tasa_oficial_banxico) AS rn
    FROM bronce.Stg_TiposCambio_API
)
DELETE FROM Tc_Rank WHERE rn > 1;

WITH Cli_Rank AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY clave_cliente ORDER BY nombre) AS rn
    FROM bronce.Stg_Clientes
)
DELETE FROM Cli_Rank WHERE rn > 1;
GO

/* ============================================================================
   FASE 4 — VALIDACIÓN Y ENRIQUECIMIENTO
   ============================================================================ */

-- Imputación: spread faltante = promedio de los spreads del mismo día
UPDATE t
SET spread_mercado_pct = (
    SELECT AVG(t2.spread_mercado_pct)
    FROM bronce.Stg_TiposCambio_API t2
    WHERE t2.fecha_consulta = t.fecha_consulta
      AND t2.spread_mercado_pct IS NOT NULL
)
FROM bronce.Stg_TiposCambio_API t
WHERE t.spread_mercado_pct IS NULL;

-- Validación: las operaciones que rompen una regla de negocio se envían a la bitácora (plata.Rechazos).
-- Una cantidad negativa se rechaza en lugar de convertirla con ABS(), porque no se sabe
-- si el error fue el signo o el tipo de operación.
INSERT INTO plata.Rechazos (origen, folio, motivo)
SELECT 'Stg_Operaciones', o.folio,
       CASE
           WHEN o.cantidad <= 0                          THEN 'Cantidad menor o igual a cero'
           WHEN o.tipo_operacion NOT IN ('Compra','Venta') THEN 'Tipo de operación inválido: ' + o.tipo_operacion
           WHEN d.id_divisa IS NULL                      THEN 'Divisa fuera de catálogo: ' + o.codigo_divisa
           WHEN c.id_cliente IS NULL AND sc.id_cliente IS NULL THEN 'Cliente inexistente: ' + o.clave_cliente
           WHEN e.id_empleado IS NULL                    THEN 'Empleado inexistente'
       END
FROM bronce.Stg_Operaciones o
LEFT JOIN plata.Divisas    d  ON d.codigo      = o.codigo_divisa
LEFT JOIN plata.Clientes   c  ON c.id_cliente  = o.id_cliente
LEFT JOIN bronce.Stg_Clientes sc ON sc.id_cliente = o.id_cliente
LEFT JOIN plata.Empleados  e  ON e.id_empleado = o.id_empleado
WHERE o.cantidad <= 0
   OR o.tipo_operacion NOT IN ('Compra','Venta')
   OR d.id_divisa IS NULL
   OR (c.id_cliente IS NULL AND sc.id_cliente IS NULL)
   OR e.id_empleado IS NULL;

DELETE o FROM bronce.Stg_Operaciones o
WHERE o.folio IN (SELECT folio FROM plata.Rechazos WHERE origen = 'Stg_Operaciones');

-- Enriquecimiento e integración al modelo de PLATA (todo o nada)
BEGIN TRANSACTION;

    -- Clientes nuevos (los que ya existen no se vuelven a insertar)
    INSERT INTO plata.Clientes (id_cliente, nombre, telefono)
    SELECT s.id_cliente, s.nombre, s.telefono
    FROM bronce.Stg_Clientes s
    WHERE NOT EXISTS (SELECT 1 FROM plata.Clientes c WHERE c.id_cliente = s.id_cliente);

    -- Tipos de cambio: compra y venta se calculan con la tasa oficial y el spread
    --   compra = tasa * (1 - spread/100)     venta = tasa * (1 + spread/100)
    INSERT INTO plata.TiposCambio (id_tipo, id_divisa, compra, venta, fecha)
    SELECT (SELECT MAX(id_tipo) FROM plata.TiposCambio) + ROW_NUMBER() OVER (ORDER BY d.id_divisa),
           d.id_divisa,
           ROUND(a.tasa_oficial_banxico * (1 - a.spread_mercado_pct / 100), 2),
           ROUND(a.tasa_oficial_banxico * (1 + a.spread_mercado_pct / 100), 2),
           a.fecha_consulta
    FROM bronce.Stg_TiposCambio_API a
    JOIN plata.Divisas d ON d.codigo = a.codigo_divisa
    WHERE NOT EXISTS (SELECT 1 FROM plata.TiposCambio t
                      WHERE t.id_divisa = d.id_divisa AND t.fecha = a.fecha_consulta);

    -- Operaciones: se busca el tipo de cambio de la misma divisa y fecha y se calcula total_mxn
    INSERT INTO plata.Operaciones (id_operacion, id_cliente, id_empleado, id_divisa, id_tipo,
                                   tipo_operacion, cantidad, total_mxn, fecha)
    SELECT o.id_operacion, o.id_cliente, o.id_empleado, d.id_divisa, t.id_tipo,
           o.tipo_operacion, o.cantidad,
           ROUND(o.cantidad * CASE o.tipo_operacion WHEN 'Compra' THEN t.compra ELSE t.venta END, 2),
           o.fecha_operacion
    FROM bronce.Stg_Operaciones o
    JOIN plata.Divisas     d ON d.codigo    = o.codigo_divisa
    JOIN plata.TiposCambio t ON t.id_divisa = d.id_divisa AND t.fecha = o.fecha_operacion;

COMMIT TRANSACTION;
GO

-- Diferencial cambiario: tasa aplicada contra la tasa oficial del día
SELECT o.id_operacion, d.codigo, o.tipo_operacion,
       CASE o.tipo_operacion WHEN 'Compra' THEN t.compra ELSE t.venta END AS tasa_aplicada,
       a.tasa_oficial_banxico,
       CASE o.tipo_operacion WHEN 'Compra' THEN t.compra ELSE t.venta END
           - a.tasa_oficial_banxico AS diferencial_cambiario
FROM plata.Operaciones o
JOIN plata.Divisas     d ON d.id_divisa = o.id_divisa
JOIN plata.TiposCambio t ON t.id_tipo   = o.id_tipo
LEFT JOIN bronce.Stg_TiposCambio_API a
       ON a.codigo_divisa = d.codigo AND a.fecha_consulta = o.fecha
WHERE o.fecha = '2026-08-06';

SELECT * FROM plata.Rechazos;
GO

/* ============================================================================
   CONSULTAS DE VALIDACIÓN DEL MODELO EN PLATA (deben regresar 0 filas)
   ============================================================================ */

-- 1) Operaciones cuyo tipo de cambio es de otra divisa o de otra fecha
SELECT o.id_operacion, o.id_divisa, t.id_divisa AS divisa_tipo, o.fecha, t.fecha AS fecha_tipo
FROM plata.Operaciones o
JOIN plata.TiposCambio t ON t.id_tipo = o.id_tipo
WHERE o.id_divisa <> t.id_divisa OR o.fecha <> t.fecha;

-- 2) Operaciones cuyo total_mxn no cuadra con la tasa aplicada
SELECT o.id_operacion, o.tipo_operacion, o.cantidad, o.total_mxn,
       ROUND(o.cantidad * CASE o.tipo_operacion WHEN 'Compra' THEN t.compra ELSE t.venta END, 2) AS total_esperado
FROM plata.Operaciones o
JOIN plata.TiposCambio t ON t.id_tipo = o.id_tipo
WHERE o.total_mxn <> ROUND(o.cantidad * CASE o.tipo_operacion WHEN 'Compra' THEN t.compra ELSE t.venta END, 2);

-- 3) Tipos de cambio con venta menor o igual a compra (no debería pasar)
SELECT * FROM plata.TiposCambio WHERE venta <= compra;
GO
