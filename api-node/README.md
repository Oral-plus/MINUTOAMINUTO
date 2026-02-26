# API Node.js - Render + SQL Server

Backend Express + SQL Server para desplegar en Render.

## Endpoints

- `GET /health` -> estado de la API (sin DB)
- `GET /health/db` -> valida conexion SQL Server
- `GET /test` -> prueba API + DB
- `GET /vendedores`
- `GET /supervisores`
- `GET /llamadas`
- `GET /ppvc`
- `GET /rvc`
- `GET /alertas`
- `POST /transcribe` -> transcripción de audio vía Gemini

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
- `GEMINI_API_KEY` (obligatoria para `/transcribe`)
- `GEMINI_MODEL` (default `gemini-2.5-flash`)
- `GEMINI_FALLBACK_MODEL` (default `gemini-2.5-flash-lite`)

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
