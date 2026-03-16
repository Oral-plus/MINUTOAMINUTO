-- Migración: Correlación dual punto A + punto B
-- Crea registro_llamadas si no existe, o agrega columnas faltantes.
--
-- Requisito: La base de datos minuto_a_minuto debe existir.
-- Si es BD nueva, ejecutar primero: minuto_a_minuto_schema.sql

USE minuto_a_minuto;
GO

-- 1. Crear tabla registro_llamadas si no existe (con todas las columnas)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'registro_llamadas')
BEGIN
  CREATE TABLE registro_llamadas (
    id NVARCHAR(50) PRIMARY KEY,
    fecha DATE NOT NULL,
    horaInicio DATETIME NOT NULL,
    horaFin DATETIME NOT NULL,
    duracionMinutos INT NOT NULL,
    tipoLlamada NVARCHAR(50) NOT NULL,
    cargoLider NVARCHAR(50) NOT NULL,
    zona NVARCHAR(100) NOT NULL,
    nombreLider NVARCHAR(255) NOT NULL,
    nombreContactado NVARCHAR(255) NOT NULL,
    numeroContacto NVARCHAR(50) NULL,
    numeroPropietario NVARCHAR(50) NULL,
    clientesProgramados INT DEFAULT 0,
    clientesVisitados INT DEFAULT 0,
    ventaDia FLOAT DEFAULT 0,
    recaudoDia FLOAT DEFAULT 0,
    cumplioMeta INT DEFAULT 0,
    coincidenciaPpvcRvc INT DEFAULT 0,
    conversion60 INT DEFAULT 0,
    recuperacionPerdidos INT DEFAULT 0,
    observaciones NVARCHAR(MAX) NULL,
    confirmacionVeracidad INT NOT NULL,
    rutaGrabacion NVARCHAR(500) NULL,
    rutaGrabacionPuntoB NVARCHAR(500) NULL,
    transcripcionTexto NVARCHAR(MAX) NULL,
    latitud FLOAT NULL,
    longitud FLOAT NULL,
    fechaCreacion DATETIME DEFAULT GETDATE()
  );
  PRINT 'Tabla registro_llamadas creada.';
END
ELSE
BEGIN
  -- 2. Si ya existe, agregar columnas que falten
  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('registro_llamadas') AND name = 'numeroContacto')
    ALTER TABLE registro_llamadas ADD numeroContacto NVARCHAR(50) NULL;
  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('registro_llamadas') AND name = 'numeroPropietario')
    ALTER TABLE registro_llamadas ADD numeroPropietario NVARCHAR(50) NULL;
  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('registro_llamadas') AND name = 'rutaGrabacionPuntoB')
    ALTER TABLE registro_llamadas ADD rutaGrabacionPuntoB NVARCHAR(500) NULL;
  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('registro_llamadas') AND name = 'latitud')
    ALTER TABLE registro_llamadas ADD latitud FLOAT NULL;
  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('registro_llamadas') AND name = 'longitud')
    ALTER TABLE registro_llamadas ADD longitud FLOAT NULL;
  PRINT 'Columnas de registro_llamadas actualizadas.';
END;

-- 3. Vendedores y supervisores: columna telefono
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'vendedores')
  AND NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('vendedores') AND name = 'telefono')
  ALTER TABLE vendedores ADD telefono NVARCHAR(50) NULL;

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'supervisores')
  AND NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('supervisores') AND name = 'telefono')
  ALTER TABLE supervisores ADD telefono NVARCHAR(50) NULL;
