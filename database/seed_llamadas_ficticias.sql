-- =============================================================
-- REGISTROS FICTICIOS DE LLAMADAS
-- Inserta datos de demostración en registro_llamadas.
-- Ejecutar en SQL Server Management Studio.
-- Si los IDs ya existen, primero: DELETE FROM registro_llamadas WHERE id LIKE 'fict-%';
-- =============================================================

USE minuto_a_minuto;
GO

DECLARE @fecha DATE = CAST(GETDATE() AS DATE);

INSERT INTO registro_llamadas (
  id, fecha, horaInicio, horaFin, duracionMinutos, tipoLlamada, cargoLider,
  zona, nombreLider, nombreContactado, numeroContacto, numeroPropietario,
  clientesProgramados, clientesVisitados, ventaDia, recaudoDia, cumplioMeta,
  coincidenciaPpvcRvc, conversion60, recuperacionPerdidos, observaciones,
  confirmacionVeracidad
) VALUES
  ('fict-001', @fecha, DATEADD(MINUTE, 8*60+30, @fecha), DATEADD(MINUTE, 8*60+35, @fecha), 5, 'manana', 'coach', 'Zona Norte', 'Juan Perez', 'Maria Lopez', '3015551234', '3001112233', 12, 10, 1850000, 920000, 1, 1, 2, 1, 'Llamada mañana. Planeación zona Norte.', 1),
  ('fict-002', @fecha, DATEADD(MINUTE, 9*60+0, @fecha), DATEADD(MINUTE, 9*60+8, @fecha), 8, 'manana', 'coach', 'Zona Norte', 'Juan Perez', 'Carlos Mendoza', '3015552234', '3001112233', 10, 9, 1420000, 680000, 1, 1, 1, 0, 'Buen avance. Objetivos claros.', 1),
  ('fict-003', @fecha, DATEADD(MINUTE, 10*60+15, @fecha), DATEADD(MINUTE, 10*60+22, @fecha), 7, 'manana', 'coach', 'Zona Norte', 'Juan Perez', 'Andres Martinez', '3015553234', '3001112233', 8, 5, 680000, 320000, 0, 0, 0, 0, 'Necesita refuerzo en visitas.', 1),
  ('fict-004', @fecha, DATEADD(MINUTE, 14*60+0, @fecha), DATEADD(MINUTE, 14*60+12, @fecha), 12, 'tarde', 'coach', 'Zona Norte', 'Juan Perez', 'Maria Lopez', '3015551234', '3001112233', 12, 11, 2100000, 1150000, 1, 1, 2, 1, 'Cierre de tarde. Meta superada.', 1),
  ('fict-005', @fecha, DATEADD(MINUTE, 16*60+30, @fecha), DATEADD(MINUTE, 16*60+38, @fecha), 8, 'tarde', 'coach', 'Zona Centro', 'Ana Garcia', 'Laura Rodriguez', '3015554234', '3002223344', 15, 14, 2450000, 1320000, 1, 1, 3, 2, 'Excelente ejecución. Top del equipo.', 1),
  ('fict-006', @fecha, DATEADD(MINUTE, 11*60+0, @fecha), DATEADD(MINUTE, 11*60+6, @fecha), 6, 'kam', 'kam', 'Nacional', 'Roberto Perez', 'Ana Garcia', '3002223344', '3003334455', 30, 28, 0, 0, 1, 1, 0, 0, 'Revisión KAM. Disciplina operativa en orden.', 1);

PRINT '6 registros ficticios insertados en registro_llamadas.';
GO
