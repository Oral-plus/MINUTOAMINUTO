# API Node.js - Render + SQL Server

Backend Express + SQL Server para desplegar en Render.

## Endpoints

- `GET /health` -> estado de la API (sin DB)
- `GET /health/db` -> valida conexion SQL Server
- `GET /api/test` -> prueba API + DB
- `GET /api/invoices/by-cardcode/:cardcode` -> consulta principal

## Variables de entorno (Render)

- `DB_HOST` (publico/ruteable desde internet)
- `DB_PORT` (`1433`)
- `DB_NAME`
- `DB_USER`
- `DB_PASS`
- `DB_ENCRYPT` (`false` recomendado sin certificado valido)
- `DB_TRUST_SERVER_CERT` (`true` recomendado en entornos privados)
- `DB_CONNECT_TIMEOUT` (`30000`)
- `DB_REQUEST_TIMEOUT` (`30000`)

## Despliegue en Render

Configura un **Web Service**:

- Runtime: `Node`
- Root Directory: `api-node`
- Build Command: `npm install --no-audit --no-fund`
- Start Command: `npm start`
- Health Check Path: `/health`

## Prueba local

```bash
cd api-node
npm install
npm start
```

## Nota clave de red

Render no puede conectarse a SQL en IP privada (`192.168.x.x`) sin VPN/tunel/IP publica.
El valor de `DB_HOST` debe ser accesible desde internet.
