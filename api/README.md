# API PHP - Minuto a Minuto

API REST que conecta la app Flutter con SQL Server.

## Requisitos

- PHP 7.4+ con extensión `sqlsrv` o `pdo_sqlsrv`
- SQL Server con la base de datos `minuto_a_minuto` creada (ejecute el script `database/minuto_a_minuto_schema.sql`)

## Configuración

Edite `config/database.php`:

- `DB_HOST`: IP del SQL Server (ej: 192.168.2.244)
- `DB_NAME`: Nombre de la base de datos (ej: minuto_a_minuto)
- `DB_USER` / `DB_PASS`: Credenciales

## Instalación

1. Copie la carpeta `api` a su servidor web (Apache, nginx, XAMPP, etc.)
2. Configure la URL base en la app Flutter: `lib/config/api_config.dart`
   - Ejemplo: `http://192.168.2.244/api` si la API está en la raíz
   - O: `http://192.168.2.244/minutoaminuto/api` si está en subcarpeta

## Endpoints

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | /test | Probar conexión |
| GET | /vendedores | Listar vendedores |
| GET | /vendedores/{id} | Obtener vendedor |
| GET | /supervisores | Listar supervisores |
| GET | /supervisores/{id} | Obtener supervisor |
| GET | /llamadas?desde=&hasta= | Listar llamadas |
| POST | /llamadas | Registrar llamada |
| GET | /ppvc?fecha=&vendedorId= | PPVC |
| GET | /rvc?fecha=&vendedorId= | RVC |
| GET | /alertas?resuelta=0 | Alertas pendientes |
| POST | /ubicaciones | Guardar ubicación |

## En la app Flutter

En `lib/config/api_config.dart`:
- `baseUrl`: URL donde está la API (ej: http://192.168.2.244/api)
- `useRemoteApi`: true para usar SQL Server, false para SQLite local
