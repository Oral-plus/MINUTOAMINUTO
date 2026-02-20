# Portal Web Administrador - Minuto a Minuto

Portal web PHP para que los administradores gestionen el sistema sin depender solo de la app móvil.

## Acceso

- **URL**: `/admin/` (ej: `http://tu-servidor/minutoaminuto/admin/`)
- **Usuario por defecto**: `admin`
- **Contraseña por defecto**: `minuto2025`

### Cambiar credenciales (producción)

Variables de entorno:

- `ADMIN_USER`: usuario
- `ADMIN_PASS`: contraseña

## Funcionalidades

- **Dashboard**: estadísticas (supervisores, vendedores, llamadas totales y de hoy)
- **Supervisores**: listar, agregar y eliminar (Coach, KAM, Jefe)
- **Vendedores**: listar, agregar y eliminar (asignación de coach)
- **Llamadas**: ver registro con filtros por fecha y zona, incluye transcripciones

## Requisitos

- PHP con extensión `sqlsrv` o `pdo_sqlsrv` (SQL Server)
- Misma base de datos que la API (`api/config/database.php`)

## Despliegue

Ver la guía general en la raíz del proyecto: [DEPLOY.md](../DEPLOY.md)
