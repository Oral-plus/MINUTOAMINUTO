# API Node.js - Render + SQL Server

## Endpoints

- `GET /health` -> estado de la API (sin DB)
- `GET /health/db` -> estado de conexión SQL Server
- `GET /api/test` -> prueba completa de API + DB
- `GET /api/invoices/by-cardcode/:cardcode` -> facturas por CardCode

## Variables de entorno (Render)

- `DB_HOST` (publico/ruteable desde internet)
- `DB_PORT` (default `1433`)
- `DB_NAME`
- `DB_USER`
- `DB_PASS`
- `DB_ENCRYPT` (`false` recomendado si no hay cert SSL valido)
- `DB_TRUST_SERVER_CERT` (`true` en escenarios sin CA publica)
- `DB_CONNECT_TIMEOUT` (`30000`)
- `DB_REQUEST_TIMEOUT` (`30000`)

## Local

```bash
npm install
npm start
```

## Render (Web Service)

- Runtime: `Node`
- Root Directory: `api-node`
- Build Command: `npm ci`
- Start Command: `npm start`
- Health Check Path: `/health`

## Importante sobre SQL Server

Si usas SQL en red local (`192.168.x.x`), Render no podra conectarse sin exponerlo
por IP publica/tunel/VPN. En Render, `DB_HOST` debe ser accesible desde internet.
# API Node.js - Minuto a Minuto

Backend Express + SQL Server listo para Render.

## 1) Estructura

- `server.js`
- `package.json`
- `.gitignore`

## 2) Variables de entorno (Render)

Configura estas variables en tu Web Service:

- `DB_HOST` (publico/ruteable desde internet)
- `DB_PORT=1433`
- `DB_NAME`
- `DB_USER`
- `DB_PASS`
- `DB_ENCRYPT=false` (si no tienes certificado valido)
- `DB_TRUST_SERVER_CERT=true`
- `DB_CONNECT_TIMEOUT=30000`
- `DB_REQUEST_TIMEOUT=30000`
- `DB_INVOICES_TABLE=CONSULTA_CARTERA` (opcional)

## 3) Despliegue en Render

1. Sube esta carpeta al repositorio GitHub.
2. En Render crea un **Web Service**.
3. Configura:
   - Runtime: `Node`
   - Root Directory: `api-node`
   - Build Command: `npm ci`
   - Start Command: `npm start`
   - Health Check Path: `/health`
4. Agrega variables de entorno (seccion anterior).
5. Deploy.

## 4) Endpoints de verificacion

- `GET /health` -> API viva
- `GET /health/db` -> Conexion SQL Server + tabla
- `GET /api/test` -> Test rapido API/DB
- `GET /api/invoices/by-cardcode/:cardcode` -> Consulta principal
- `GET /api/invoices/all?limit=100`
- `GET /api/invoices/search?cardCode=...&docNum=...&cardName=...`

## 5) SQL Server obligatorio para Render

Render no puede llegar a IP privada `192.168.x.x` sin tunel o IP publica.

Debes tener:

1. TCP/IP habilitado en SQL Server Configuration Manager.
2. Puerto fijo `1433`.
3. Servicio SQL Server reiniciado.
4. Firewall de Windows abierto en `1433`.
5. Si hay router: port-forward `1433 -> tu-servidor-sql:1433`.
6. `DB_HOST` en Render debe ser un host accesible publicamente.

## 6) Prueba local

```bash
cd api-node
npm install
npm start
```

Luego prueba:

- `http://localhost:3005/health`
- `http://localhost:3005/health/db`
