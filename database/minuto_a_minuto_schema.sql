-- =====================================================
-- SCRIPT BASE DE DATOS - MINUTO A MINUTO
-- Compatible con: SQL Server
-- =====================================================

-- CREAR LA BASE DE DATOS (si no existe)
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'minuto_a_minuto')
BEGIN
    CREATE DATABASE minuto_a_minuto;
END
GO

-- USAR LA BASE DE DATOS
USE minuto_a_minuto;
GO

-- 1. TABLA VENDEDORES
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'vendedores')
CREATE TABLE vendedores (
    id NVARCHAR(50) PRIMARY KEY,
    nombre NVARCHAR(255) NOT NULL,
    codigo NVARCHAR(50) NOT NULL,
    zona NVARCHAR(100) NOT NULL,
    coachId NVARCHAR(50) NOT NULL,
    geolocalizacionActiva INT DEFAULT 0,
    horaInicioJornada NVARCHAR(50) NULL,
    presupuestoMensual FLOAT DEFAULT 0,
    presupuestoDiario FLOAT DEFAULT 0,
    fechaCreacion DATETIME DEFAULT GETDATE()
);

-- 2. TABLA SUPERVISORES (Coach, KAM, Jefe)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'supervisores')
CREATE TABLE supervisores (
    id NVARCHAR(50) PRIMARY KEY,
    nombre NVARCHAR(255) NOT NULL,
    codigo NVARCHAR(50) NOT NULL,
    zona NVARCHAR(100) NOT NULL,
    cargo NVARCHAR(50) NOT NULL,
    superiorId NVARCHAR(50) NULL,
    subordinadosIds NVARCHAR(MAX) NULL,
    fechaCreacion DATETIME DEFAULT GETDATE()
);

-- 3. TABLA REGISTRO DE LLAMADAS (incluye rutaGrabacion)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'registro_llamadas')
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
    transcripcionTexto NVARCHAR(MAX) NULL,
    fechaCreacion DATETIME DEFAULT GETDATE()
);

-- 4. TABLA PPVC (Plan de Visita a Clientes)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ppvc')
CREATE TABLE ppvc (
    id NVARCHAR(50) PRIMARY KEY,
    vendedorId NVARCHAR(50) NOT NULL,
    fecha DATE NOT NULL,
    zona NVARCHAR(100) NOT NULL,
    clientesProgramados INT DEFAULT 0,
    clientes60Ids NVARCHAR(MAX) NULL,
    clientesPerdidosIds NVARCHAR(MAX) NULL,
    metaVenta FLOAT DEFAULT 0,
    metaRecaudo FLOAT DEFAULT 0,
    programado2DiasAntes INT DEFAULT 0,
    fechaCreacion DATETIME DEFAULT GETDATE()
);

-- 5. TABLA RVC (Registro de Visita a Cliente)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'rvc')
CREATE TABLE rvc (
    id NVARCHAR(50) PRIMARY KEY,
    vendedorId NVARCHAR(50) NOT NULL,
    fecha DATE NOT NULL,
    zona NVARCHAR(100) NOT NULL,
    clientesVisitados INT DEFAULT 0,
    clientes60Visitados INT DEFAULT 0,
    clientesPerdidosVisitados INT DEFAULT 0,
    ventaTotal FLOAT DEFAULT 0,
    recaudoTotal FLOAT DEFAULT 0,
    clientesNoVisitados NVARCHAR(MAX) NULL,
    descuentosAplicados INT DEFAULT 0,
    fechaCreacion DATETIME DEFAULT GETDATE()
);

-- 6. TABLA ALERTAS
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'alertas')
CREATE TABLE alertas (
    id NVARCHAR(50) PRIMARY KEY,
    tipo NVARCHAR(100) NOT NULL,
    fecha DATETIME NOT NULL,
    mensaje NVARCHAR(MAX) NOT NULL,
    vendedorId NVARCHAR(50) NULL,
    supervisorId NVARCHAR(50) NULL,
    zona NVARCHAR(100) NULL,
    resuelta INT DEFAULT 0,
    fechaCreacion DATETIME DEFAULT GETDATE()
);

-- 7. TABLA UBICACIONES (Geolocalización)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ubicaciones')
CREATE TABLE ubicaciones (
    id NVARCHAR(50) PRIMARY KEY,
    vendedorId NVARCHAR(50) NOT NULL,
    fecha DATE NOT NULL,
    latitud FLOAT NOT NULL,
    longitud FLOAT NOT NULL,
    [timestamp] DATETIME NOT NULL,
    fechaCreacion DATETIME DEFAULT GETDATE()
);

-- ÍNDICES
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_llamadas_fecha' AND object_id = OBJECT_ID('registro_llamadas'))
    CREATE INDEX idx_llamadas_fecha ON registro_llamadas(fecha);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_llamadas_nombre_lider' AND object_id = OBJECT_ID('registro_llamadas'))
    CREATE INDEX idx_llamadas_nombre_lider ON registro_llamadas(nombreLider);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_llamadas_nombre_contactado' AND object_id = OBJECT_ID('registro_llamadas'))
    CREATE INDEX idx_llamadas_nombre_contactado ON registro_llamadas(nombreContactado);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_ppvc_fecha' AND object_id = OBJECT_ID('ppvc'))
    CREATE INDEX idx_ppvc_fecha ON ppvc(fecha);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_ppvc_vendedor' AND object_id = OBJECT_ID('ppvc'))
    CREATE INDEX idx_ppvc_vendedor ON ppvc(vendedorId);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_rvc_fecha' AND object_id = OBJECT_ID('rvc'))
    CREATE INDEX idx_rvc_fecha ON rvc(fecha);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_rvc_vendedor' AND object_id = OBJECT_ID('rvc'))
    CREATE INDEX idx_rvc_vendedor ON rvc(vendedorId);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_ubicaciones_vendedor' AND object_id = OBJECT_ID('ubicaciones'))
    CREATE INDEX idx_ubicaciones_vendedor ON ubicaciones(vendedorId);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_alertas_resuelta' AND object_id = OBJECT_ID('alertas'))
    CREATE INDEX idx_alertas_resuelta ON alertas(resuelta);

-- Las tablas quedan vacías. Los datos se insertan desde la app o desde su sistema.
