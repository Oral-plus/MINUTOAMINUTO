# Scripts de Base de Datos - Minuto a Minuto

## Uso del script principal

`minuto_a_minuto_schema.sql` está escrito para **SQLite** (usado por la app móvil).

### SQLite (app local)

La app Flutter usa SQLite internamente. El script sirve como referencia y para migrar datos.

### MySQL / MariaDB

- Cambiar `INSERT OR IGNORE` por `INSERT IGNORE`
- Cambiar `TEXT` por `VARCHAR(255)` o `TEXT` según necesidad
- Cambiar `REAL` por `DOUBLE`
- Cambiar `INTEGER` por `INT`
- `datetime('now')` → `NOW()` o `CURRENT_TIMESTAMP`

### SQL Server

- Quitar `IF NOT EXISTS` en `CREATE TABLE` (usar verificación previa)
- `INSERT OR IGNORE` → `INSERT` con manejo de duplicados
- `TEXT` → `NVARCHAR(MAX)` o `VARCHAR(255)`
- `REAL` → `FLOAT`
- `datetime('now')` → `GETDATE()`

### PostgreSQL

- `INSERT OR IGNORE` → `INSERT ... ON CONFLICT DO NOTHING`
- Compatible en gran parte con el script base

## Ubicación de grabaciones

Ver `UBICACION_GRABACIONES.md`.
