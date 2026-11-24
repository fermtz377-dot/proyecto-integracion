/* ============================================================================
   02_ETL_INGESTA_BRONCE.SQL
   Casa de Cambio — Cargas de datos
   Parte A: carga semilla ya validada, directo a PLATA (bootstrap del modelo).
   Parte B: ingesta cruda a BRONCE del lote nuevo del 6 de agosto de 2026,
            tal como llega de los 3 orígenes (con duplicados y errores a propósito).
   ============================================================================ */

/* ============================================================================
   PARTE A — Carga inicial semilla (datos de prueba ya coherentes) en PLATA
   10 clientes, 5 empleados, 5 divisas, 25 tipos de cambio (1 por divisa/día,
   del 1 al 5 de agosto de 2026) y 20 operaciones.
   ============================================================================ */

-- Clientes
INSERT INTO plata.Clientes (id_cliente, nombre, telefono) VALUES
    (1, 'María Fernanda López', '8112345678'),
    (2, 'Juan Carlos Ramírez', '8123456789'),
    (3, 'Ana Sofía Hernández', '8134567890'),
    (4, 'Luis Alberto García', '8145678901'),
    (5, 'Daniela Torres Méndez', '8156789012'),
    (6, 'Jorge Eduardo Salinas', '8167890123'),
    (7, 'Paola Guadalupe Cantú', '8178901234'),
    (8, 'Ricardo Treviño Garza', '8189012345'),
    (9, 'Valeria Martínez Ruiz', '8190123456'),
    (10, 'Héctor Manuel Villarreal', '8111223344');

-- Empleados
INSERT INTO plata.Empleados (id_empleado, nombre, puesto) VALUES
    (1, 'Laura Patricia Sánchez', 'Gerente de sucursal'),
    (2, 'Miguel Ángel Flores', 'Cajero'),
    (3, 'Karla Ivonne Reyes', 'Cajero'),
    (4, 'Óscar Iván Morales', 'Ejecutivo de cambio'),
    (5, 'Diana Elizabeth Castro', 'Supervisor');

-- Divisas
INSERT INTO plata.Divisas (id_divisa, nombre, codigo) VALUES
    (1, 'Dólar estadounidense', 'USD'),
    (2, 'Euro', 'EUR'),
    (3, 'Dólar canadiense', 'CAD'),
    (4, 'Libra esterlina', 'GBP'),
    (5, 'Franco suizo', 'CHF');

-- TiposCambio: un registro por divisa por día (1 = USD, 2 = EUR, 3 = CAD, 4 = GBP, 5 = CHF)
INSERT INTO plata.TiposCambio (id_tipo, id_divisa, compra, venta, fecha) VALUES
    ( 1, 1, 19.20, 19.70, '2026-08-01'),
    ( 2, 2, 20.85, 21.45, '2026-08-01'),
    ( 3, 3, 13.95, 14.50, '2026-08-01'),
    ( 4, 4, 24.30, 25.10, '2026-08-01'),
    ( 5, 5, 21.70, 22.40, '2026-08-01'),
    ( 6, 1, 19.25, 19.75, '2026-08-02'),
    ( 7, 2, 20.90, 21.50, '2026-08-02'),
    ( 8, 3, 14.00, 14.55, '2026-08-02'),
    ( 9, 4, 24.35, 25.15, '2026-08-02'),
    (10, 5, 21.75, 22.45, '2026-08-02'),
    (11, 1, 19.17, 19.67, '2026-08-03'),
    (12, 2, 20.82, 21.42, '2026-08-03'),
    (13, 3, 13.92, 14.47, '2026-08-03'),
    (14, 4, 24.27, 25.07, '2026-08-03'),
    (15, 5, 21.67, 22.37, '2026-08-03'),
    (16, 1, 19.28, 19.78, '2026-08-04'),
    (17, 2, 20.93, 21.53, '2026-08-04'),
    (18, 3, 14.03, 14.58, '2026-08-04'),
    (19, 4, 24.38, 25.18, '2026-08-04'),
    (20, 5, 21.78, 22.48, '2026-08-04'),
    (21, 1, 19.22, 19.72, '2026-08-05'),
    (22, 2, 20.87, 21.47, '2026-08-05'),
    (23, 3, 13.97, 14.52, '2026-08-05'),
    (24, 4, 24.32, 25.12, '2026-08-05'),
    (25, 5, 21.72, 22.42, '2026-08-05');

-- Operaciones: total_mxn = cantidad * compra (Compra) o cantidad * venta (Venta) del id_tipo indicado
INSERT INTO plata.Operaciones (id_operacion, id_cliente, id_empleado, id_divisa, id_tipo, tipo_operacion, cantidad, total_mxn, fecha) VALUES
    ( 1,  1, 2, 1,  1, 'Compra', 1500.00,  28800.00, '2026-08-01'),
    ( 2,  2, 3, 2,  2, 'Compra',  800.00,  16680.00, '2026-08-01'),
    ( 3,  3, 4, 1,  1, 'Venta' ,  500.00,   9850.00, '2026-08-01'),
    ( 4,  4, 2, 3,  8, 'Compra', 1200.00,  16800.00, '2026-08-02'),
    ( 5,  5, 3, 1,  6, 'Venta' , 2000.00,  39500.00, '2026-08-02'),
    ( 6,  6, 4, 4,  9, 'Compra',  300.00,   7305.00, '2026-08-02'),
    ( 7,  1, 2, 2,  7, 'Venta' ,  450.00,   9675.00, '2026-08-02'),
    ( 8,  7, 3, 5, 15, 'Compra',  600.00,  13002.00, '2026-08-03'),
    ( 9,  8, 4, 1, 11, 'Compra', 3200.00,  61344.00, '2026-08-03'),
    (10,  9, 2, 2, 12, 'Venta' , 1000.00,  21420.00, '2026-08-03'),
    (11,  2, 1, 1, 11, 'Venta' ,  750.00,  14752.50, '2026-08-03'),
    (12, 10, 3, 3, 18, 'Venta' ,  900.00,  13122.00, '2026-08-04'),
    (13,  3, 4, 4, 19, 'Venta' ,  250.00,   6295.00, '2026-08-04'),
    (14,  4, 2, 1, 16, 'Compra', 5000.00,  96400.00, '2026-08-04'),
    (15,  5, 5, 2, 17, 'Compra', 1500.00,  31395.00, '2026-08-04'),
    (16,  6, 3, 1, 21, 'Venta' , 1200.00,  23664.00, '2026-08-05'),
    (17,  7, 4, 2, 22, 'Compra', 2200.00,  45914.00, '2026-08-05'),
    (18,  8, 2, 5, 25, 'Venta' ,  400.00,   8968.00, '2026-08-05'),
    (19,  9, 3, 1, 21, 'Compra',  650.00,  12493.00, '2026-08-05'),
    (20, 10, 5, 4, 24, 'Compra',  180.00,   4377.60, '2026-08-05');
GO

/* ============================================================================
   PARTE B — Ingesta cruda a BRONCE
   Simulación: el 6 de agosto de 2026 llegan datos nuevos desde 3 orígenes
   externos. Se cargan tal cual, incluyendo duplicados y errores a propósito
   (marcados con comentarios) para que el protocolo de limpieza los detecte.
   ============================================================================ */

-- Origen 1: operaciones exportadas del sistema de caja
INSERT INTO bronce.Stg_Operaciones VALUES
('OP-0021', '2026-08-06 09:10:00', 'CLI-011',  2, 'USD',  'Compra',    1000.00),
('OP-0022', '2026-08-06 09:45:00', 'CLI-012',  3, ' eur', 'VENTA',      600.00),
('OP-0023', '2026-08-06 10:30:00', 'CLI-003',  4, 'CAD',  ' compra ',   850.00),
('OP-0023', '2026-08-06 10:30:00', 'CLI-003',  4, 'CAD',  ' compra ',   850.00),  -- duplicado
('OP-0024', '2026-08-06 11:15:00', 'cli-013 ', 2, 'GBP',  'Venta',      200.00),
('OP-0025', '2026-08-06 12:00:00', 'CLI-005',  3, 'USD',  'Venta',     -300.00),  -- cantidad negativa
('OP-0026', '2026-08-06 12:40:00', 'CLI-099',  2, 'USD',  'Compra',     500.00),  -- cliente inexistente
('OP-0027', '2026-08-06 13:05:00', 'CLI-007',  5, 'JPY',  'Compra',   10000.00),  -- divisa fuera de catálogo
('OP-0028', '2026-08-06 16:20:00', 'CLI-001',  4, 'CHF',  'Venta',      350.00),
('OP-0029', '2026-08-06 17:00:00', 'CLI-008',  3, 'EUR',  'Cambio',     400.00);  -- tipo de operación inválido

-- Origen 2: tipos de cambio oficiales (API externa)
INSERT INTO bronce.Stg_TiposCambio_API VALUES
('2026-08-06', 'USD/MXN',  19.4500, 1.30),
('2026-08-06', 'EUR/MXN',  21.1500, 1.40),
('2026-08-06', 'cad/mxn ', 14.2200, 1.95),  -- formato inconsistente
('2026-08-06', 'GBP/MXN',  24.7000, NULL),  -- spread faltante
('2026-08-06', 'CHF/MXN',  22.0500, 1.60),
('2026-08-06', 'USD/MXN',  19.4500, 1.30);  -- duplicado

-- Origen 3: clientes nuevos capturados en el CRM
INSERT INTO bronce.Stg_Clientes VALUES
('CLI-011',  '  Fernanda   Quiroga Leal ', '(811) 234-5566'),
('CLI-012',  'Roberto Garza Elizondo',     '811-345-6677'),
('cli-013 ', 'Mónica  Ibarra Solís',       '81 1456 7788'),
('CLI-012',  'Roberto Garza Elizondo',     '811-345-6677'),  -- duplicado
('CLI-003',  'Ana Sofía Hernández',        '8134567890');    -- ya existe en Clientes
GO
