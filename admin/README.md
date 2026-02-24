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

- PHP 7.4+ con `curl` o `allow_url_fopen` habilitado
- El admin se conecta a la misma API que la app Flutter

## Configuración de la API

Por defecto usa: `https://minutoaminuto-1.onrender.com` (igual que la app).

Para cambiar la URL, defina la variable de entorno:
- `API_BASE_URL`: URL base de la API (ej: `https://minutoaminuto-1.onrender.com`)

## Despliegue

Ver la guía general en la raíz del proyecto: [DEPLOY.md](../DEPLOY.md)
