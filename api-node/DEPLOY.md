# Guía de despliegue API - Minuto a Minuto

## 📋 Requisitos para conectar y guardar llamadas

### 1. Base de datos SQL Server

Debe existir la base de datos `minuto_a_minuto` con las tablas correctas.

**Ejecutar en este orden:**

1. **Schema base** (si la BD es nueva):
   ```sql
   -- En SQL Server Management Studio o sqlcmd
   -- Ejecutar: database/minuto_a_minuto_schema.sql
   ```

2. **Migración de columnas** (para registro de llamadas):
   ```sql
   -- Ejecutar: database/migration_dual_audio.sql
   ```

Esto crea/actualiza:
- `registro_llamadas` con: `numeroContacto`, `numeroPropietario`, `rutaGrabacionPuntoB`, `latitud`, `longitud`
- Columnas `telefono` en vendedores y supervisores

### 2. Variables de entorno

Crear archivo `.env` en la carpeta `api-node` (o configurar en tu hosting):

```env
# Puerto del servidor
PORT=3005

# ─── SQL Server (obligatorio) ─────────────────────────────
DB_HOST=tu-servidor-sql.ejemplo.com
DB_PORT=1433
DB_NAME=minuto_a_minuto
DB_USER=sa
DB_PASS=tu_password_seguro

# Opciones de conexión
DB_ENCRYPT=false
DB_TRUST_SERVER_CERT=true
DB_CONNECT_TIMEOUT=30000
DB_REQUEST_TIMEOUT=30000

# ─── Gemini (para transcripción de audio) ─────────────────
GEMINI_API_KEY=tu_clave_de_google_ai_studio
GEMINI_MODEL=gemini-2.5-flash
GEMINI_FALLBACK_MODEL=gemini-2.5-flash-lite
```

### 3. Accesibilidad de red

| Escenario | DB_HOST debe ser |
|-----------|------------------|
| **Local (mismo PC/servidor)** | `localhost` o `127.0.0.1` |
| **LAN** | IP interna accesible (ej: `192.168.2.244`) |
| **Render / hosting cloud** | IP o hostname PÚBLICO del SQL Server |
| **Azure SQL** | `tu-servidor.database.windows.net` |

⚠️ **Importante:** Si usas Render, Heroku u otro cloud, el servidor NO puede conectarse a IPs privadas (`192.168.x.x`). El SQL Server debe estar:
- En la nube (Azure, AWS RDS, etc.), o
- Expuesto con un túnel (ngrok, Cloudflare Tunnel), o
- En la misma red del hosting

### 4. URL de la API en la app Flutter

La app usa `http://minutoamimuto.oral-plus.com` por defecto.

**Para producción:**
- La URL debe ser HTTPS si el servidor usa SSL
- Si nginx devuelve **301 Moved Permanently**, configurar:
  - Redirección HTTP→HTTPS correcta, o
  - Usar la URL final (con https) en `ApiConfig.baseUrl`

**Para pruebas locales:**
```dart
// En lib/config/api_config.dart o al compilar:
// --dart-define=API_BASE_URL=http://192.168.2.253:3005
```

### 5. Estructura de archivos para subir

```
api-node/
├── server.js          ← Código principal
├── package.json       ← Dependencias
├── .env               ← Tus variables (NO subir a Git si tiene secretos)
├── .env.example       ← Plantilla (sin secretos)
├── README.md
└── DEPLOY.md          ← Esta guía

database/              ← Scripts SQL (ejecutar manualmente en el servidor)
├── minuto_a_minuto_schema.sql
└── migration_dual_audio.sql
```

### 6. Comandos de despliegue

**Instalación local:**
```bash
cd api-node
npm install
cp .env.example .env   # y editar .env con tus valores
npm start
```

**Render:**
- Root Directory: `api-node`
- Build: `npm install --no-audit --no-fund`
- Start: `npm start`
- Añadir todas las variables de entorno en el panel de Render

### 7. Verificación

```bash
# Salud general
curl https://tu-dominio.com/health

# Conexión a BD
curl https://tu-dominio.com/health/db

# Insertar llamada (POST)
curl -X POST https://tu-dominio.com/llamadas \
  -H "Content-Type: application/json" \
  -d '{"fecha":"2025-03-06","horaInicio":"2025-03-06T10:00:00","horaFin":"2025-03-06T10:05:00","duracionMinutos":5,"tipoLlamada":"manana","cargoLider":"coach","zona":"Z1","nombreLider":"Test","nombreContactado":"Cliente","observaciones":"Prueba","confirmacionVeracidad":1}'
```

### 8. Error 301 (nginx)

Si la app recibe `301 Moved Permanently`:
- La URL en la app usa `http://` pero el servidor redirige a `https://`
- **Solución:** Usar `https://minutoamimuto.oral-plus.com` en `ApiConfig.baseUrl`
- O configurar nginx para que POST no redirija (proxy directo al Node en el mismo puerto)
