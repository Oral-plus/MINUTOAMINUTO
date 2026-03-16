-- =============================================================
-- SCRIPT COMPLETO: registro_llamadas
-- Crea la BD, la tabla y agrega campos que falten.
-- Ejecutar en SQL Server Management Studio o sqlcmd.
-- =============================================================

-- 1. Crear base de datos si no existe
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'minuto_a_minuto')
BEGIN
  CREATE DATABASE minuto_a_minuto;
  PRINT 'Base de datos minuto_a_minuto creada.';
END
GO

USE minuto_a_minuto;
GO

-- 2. Crear tabla registro_llamadas si no existe (con TODAS las columnas)
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
    confirmacionVeracidad INT NOT NULL DEFAULT 1,
    rutaGrabacion NVARCHAR(500) NULL,
    rutaGrabacionPuntoB NVARCHAR(500) NULL,
    transcripcionTexto NVARCHAR(MAX) NULL,
    latitud FLOAT NULL,
    longitud FLOAT NULL,
    fechaCreacion DATETIME DEFAULT GETDATE()
  );
  PRINT 'Tabla registro_llamadas creada con todas las columnas.';
END
ELSE
BEGIN
  -- 3. Si la tabla ya existe, agregar columnas que falten
  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('registro_llamadas') AND name = 'numeroContacto')
  BEGIN
    ALTER TABLE registro_llamadas ADD numeroContacto NVARCHAR(50) NULL;
    PRINT 'Columna numeroContacto agregada.';
  END

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('registro_llamadas') AND name = 'numeroPropietario')
  BEGIN
    ALTER TABLE registro_llamadas ADD numeroPropietario NVARCHAR(50) NULL;
    PRINT 'Columna numeroPropietario agregada.';
  END

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('registro_llamadas') AND name = 'rutaGrabacion')
  BEGIN
    ALTER TABLE registro_llamadas ADD rutaGrabacion NVARCHAR(500) NULL;
    PRINT 'Columna rutaGrabacion agregada.';
  END

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('registro_llamadas') AND name = 'rutaGrabacionPuntoB')
  BEGIN
    ALTER TABLE registro_llamadas ADD rutaGrabacionPuntoB NVARCHAR(500) NULL;
    PRINT 'Columna rutaGrabacionPuntoB agregada.';
  END

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('registro_llamadas') AND name = 'transcripcionTexto')
  BEGIN
    ALTER TABLE registro_llamadas ADD transcripcionTexto NVARCHAR(MAX) NULL;
    PRINT 'Columna transcripcionTexto agregada.';
  END

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('registro_llamadas') AND name = 'latitud')
  BEGIN
    ALTER TABLE registro_llamadas ADD latitud FLOAT NULL;
    PRINT 'Columna latitud agregada.';
  END

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('registro_llamadas') AND name = 'longitud')
  BEGIN
    ALTER TABLE registro_llamadas ADD longitud FLOAT NULL;
    PRINT 'Columna longitud agregada.';
  END

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('registro_llamadas') AND name = 'fechaCreacion')
  BEGIN
    ALTER TABLE registro_llamadas ADD fechaCreacion DATETIME DEFAULT GETDATE() NULL;
    PRINT 'Columna fechaCreacion agregada.';
  END

  PRINT 'Columnas de registro_llamadas verificadas/actualizadas.';
END
GO

-- 4. Índices para consultas rápidas
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_llamadas_fecha' AND object_id = OBJECT_ID('registro_llamadas'))
BEGIN
  CREATE INDEX idx_llamadas_fecha ON registro_llamadas(fecha);
  PRINT 'Índice idx_llamadas_fecha creado.';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_llamadas_nombre_contactado' AND object_id = OBJECT_ID('registro_llamadas'))
BEGIN
  CREATE INDEX idx_llamadas_nombre_contactado ON registro_llamadas(nombreContactado);
  PRINT 'Índice idx_llamadas_nombre_contactado creado.';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_llamadas_numero' AND object_id = OBJECT_ID('registro_llamadas'))
BEGIN
  CREATE INDEX idx_llamadas_numero ON registro_llamadas(numeroPropietario, numeroContacto);
  PRINT 'Índice idx_llamadas_numero creado (para correlación dual).';
END

PRINT '=== Setup registro_llamadas completado ===';
