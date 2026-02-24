# API PHP - Minuto a Minuto

API REST conectada directamente a SQL Server.

## Requisitos

- PHP 7.4+ con extensión `sqlsrv` o `pdo_sqlsrv`
- SQL Server con base `minuto_a_minuto`
- Tablas creadas con `database/minuto_a_minuto_schema.sql`

## Variables de entorno recomendadas

- `DB_HOST` (ej: `192.168.2.244`)
- `DB_SERVER` (opcional; prioridad sobre DB_HOST, ej `host,1433` o `host\SQLEXPRESS`)
- `DB_PORT` (por defecto `1433`)
- `DB_NAME` (ej: `minuto_a_minuto`)
- `DB_USER`
- `DB_PASS`
- `DB_ENCRYPT` (`true/false`, por defecto `false`)
- `DB_TRUST_SERVER_CERT` (`true/false`, por defecto `true`)
- `DB_LOGIN_TIMEOUT` (segundos, por defecto `8`)
- `DB_QUERY_TIMEOUT` (segundos, por defecto `20`)
- `APP_DEBUG` (`1` para ver mensajes detallados)

## Publicación IIS (recomendado)

1. Copie `api/` al servidor IIS.
2. Configure un sitio/aplicación que apunte a esa carpeta.
3. Habilite `index.php` como documento predeterminado.
4. Verifique:
   - `GET /health/db` -> debe responder `success: true`.

## Endpoints

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/` | Estado de la API |
| GET | `/health/db` | Salud y conexión SQL Server |
| GET | `/vendedores` | Listar vendedores |
| GET | `/vendedores/{id}` | Obtener vendedor |
| POST | `/vendedores` | Upsert vendedor |
| DELETE | `/vendedores/{id}` | Eliminar vendedor |
| GET | `/supervisores` | Listar supervisores |
| GET | `/supervisores/{id}` | Obtener supervisor |
| POST | `/supervisores` | Upsert supervisor |
| DELETE | `/supervisores/{id}` | Eliminar supervisor |
| GET | `/llamadas?desde=YYYY-MM-DD&hasta=YYYY-MM-DD` | Listar llamadas |
| POST | `/llamadas` | Upsert llamada |
| PATCH | `/llamadas/{id}` | Actualizar observaciones/audio/transcripción |
| GET | `/ppvc?fecha=YYYY-MM-DD[&vendedorId=...]` | PPVC |
| POST | `/ppvc` | Upsert PPVC |
| GET | `/rvc?fecha=YYYY-MM-DD[&vendedorId=...]` | RVC |
| POST | `/rvc` | Upsert RVC |
| GET | `/alertas?resuelta=0` | Alertas |
| POST | `/alertas` | Upsert alerta |
| POST | `/ubicaciones` | Upsert ubicación |
| GET | `/audio?id={llamadaId}` | Obtener audio |

## Integración Flutter

En `lib/config/api_config.dart`:
- `baseUrl` (principal)
- `fallbackBaseUrl` (respaldo)
- `useRemoteApi = true`

## Despliegue en Render (Docker)

Este repositorio ya incluye `render.yaml` apuntando a `rootDir: api`.

1. En Render, abra su servicio y ejecute **Manual Deploy** del último commit.
2. Configure variables:
   - `DB_HOST`
   - `DB_NAME`
   - `DB_USER`
   - `DB_PASS`
   - `DB_PORT=1433`
   - `APP_DEBUG=1` (temporal para diagnóstico)
3. Verifique en navegador:
   - `GET /test`
   - `GET /health/db`
4. Cuando ya esté estable, cambie `APP_DEBUG=0`.

Notas:
- `/test` valida solo que la API esté arriba (útil para health check de Render).
- `/health/db` valida conectividad real con SQL Server y devuelve diagnóstico de red.
