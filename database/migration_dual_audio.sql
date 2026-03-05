-- Migración: Correlación dual punto A + punto B
-- Ejecutar en SQL Server si la tabla ya existe

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('registro_llamadas') AND name = 'numeroContacto')
  ALTER TABLE registro_llamadas ADD numeroContacto NVARCHAR(50) NULL;

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('registro_llamadas') AND name = 'numeroPropietario')
  ALTER TABLE registro_llamadas ADD numeroPropietario NVARCHAR(50) NULL;

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('registro_llamadas') AND name = 'rutaGrabacionPuntoB')
  ALTER TABLE registro_llamadas ADD rutaGrabacionPuntoB NVARCHAR(500) NULL;

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('vendedores') AND name = 'telefono')
  ALTER TABLE vendedores ADD telefono NVARCHAR(50) NULL;

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('supervisores') AND name = 'telefono')
  ALTER TABLE supervisores ADD telefono NVARCHAR(50) NULL;
