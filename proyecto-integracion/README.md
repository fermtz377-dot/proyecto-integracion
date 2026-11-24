# Sistema de Gestión y Análisis de Operaciones de una Casa de Cambio
### Integración de Datos en SQL Server

**Materia:** Integración de Datos | Universidad Iberoamericana León
**Equipo:** 4 | **Tablero Trello:** [Enlace a Trello]

![Logo del Negocio](assets/logo_negocio.png)

## 1. Descripción del Proyecto
Una casa de cambio opera con fuentes de datos dispersas: caja, CRM y una API de tipos de cambio, lo que genera registros duplicados, campos vacíos y reportes poco confiables. Este proyecto construye una base relacional en **Microsoft SQL Server**, limpia los datos mediante un proceso ETL y garantiza su integridad, con el objetivo de ofrecer un análisis eficiente del volumen operado por divisa y apoyar decisiones de negocio.

## 2. Arquitectura de Integración (SQL Server)
![Flujo de Integración Medallón](assets/flujo_medallon_sql.png)

* **Esquema `bronce` (Ingesta):** Tablas espejo con carga cruda de las fuentes (sistema de caja, CRM, API de tipos de cambio) sin alterar tipos de datos originales.
* **Esquema `plata` (Transformación y QA):** Limpieza de nulos, estandarización de textos, eliminación de duplicados (vía `ROW_NUMBER()`) y validación de integridad referencial, con bitácora de operaciones rechazadas.
* **Esquema `oro` (Consumo y BI):** Vistas consolidadas (`vw_OperacionesDetalle`, `vw_Clientes360`, `vw_ResumenKPIDivisa`) y métricas agregadas para responder las preguntas de negocio.

## 3. Modelo Entidad-Relación (DER)
![Diagrama Entidad-Relación](assets/diagrama_der_sqlserver.png)

Tablas principales: `Clientes`, `Empleados`, `Divisas`, `TiposCambio` y `Operaciones` (tabla de hechos central, enlazada por llave foránea a las cuatro anteriores).

## 4. Estructura del Repositorio (`/src`)
* `01_ddl_arquitectura_der.sql`: Creación de base de datos, esquemas y tablas relacionales.
* `02_etl_ingesta_bronce.sql`: Scripts de carga inicial (`BULK INSERT` / `INSERT`).
* `03_etl_limpieza_plata.sql`: Procedimientos almacenados de limpieza y reglas de calidad.
* `04_vistas_gold_bi.sql`: Vistas finales y consultas KPI.

## 5. Integrantes y Roles (4 Roles Oficiales)
* **Data Architect / SQL Specialist:** Sofía Elizondo
* **Data Engineer / Pipeline Lead:** Fernando Martínez
* **Data Quality & QA Specialist:** Emiliano Jesuri
* **Líder de Proyecto:** Romina Pazos
* **BI & Analytics Specialist:** Heber
