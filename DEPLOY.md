# Guía de despliegue - Minuto a Minuto

Despliegue completo: API PHP, portal admin web y opcionalmente API Dart.

---

## 1. Servidor PHP (API + Admin)

Necesitas un servidor con **PHP** y **SQL Server** (extensiones `sqlsrv` o `pdo_sqlsrv`).

### Opciones típicas

- **VPS** (DigitalOcean, Linode, etc.): instalar PHP + extensión SQL Server
- **Hosting Windows** con SQL Server: IIS + PHP
- **Hosting compartido**: verificar que ofrezca SQL Server

### Estructura en el servidor

```
/public_html/                    (o raíz del sitio)
├── api/
│   ├── index.php
│   ├── config/
│   │   └── database.php
│   ├── endpoints/
│   └── .htaccess
├── admin/
│   ├── index.php
│   ├── dashboard.php
│   ├── supervisores.php
│   ├── vendedores.php
│   ├── llamadas.php
│   ├── config.php
│   ├── assets/
│   ├── includes/
│   └── .htaccess
└── assets/
    └── logo_oral_plus.png
```

### Configurar base de datos

**Opción A – Variables de entorno (recomendado en producción):**

```
DB_HOST=tu-servidor-sql
DB_NAME=minuto_a_minuto
DB_USER=tu_usuario
DB_PASS=tu_contraseña
DB_PORT=1433
```

**Opción B – Editar** `api/config/database.php` con los valores por defecto.

### Configurar credenciales del admin

Por defecto: `admin` / `minuto2025`.

Para producción, define variables de entorno:

- `ADMIN_USER`: usuario del portal
- `ADMIN_PASS`: contraseña

O edita `admin/config.php` temporalmente (no recomendado en producción).

### URLs tras el despliegue

| Componente | URL ejemplo |
|------------|-------------|
| API | `https://tudominio.com/api/` |
| Admin | `https://tudominio.com/admin/` |

Si está en un subdirectorio: `https://tudominio.com/minutoaminuto/admin/`

---

## 2. API Dart (Render, opcional)

Si usas la API Dart en lugar de la PHP:

1. Sigue `api_server/DEPLOY_RENDER.md`
2. En Flutter, apunta `api_config.dart` a la URL de Render

---

## 3. App Flutter

En `lib/config/api_config.dart`:

```dart
static const String baseUrl = 'https://tudominio.com/api';  // API PHP
// o
static const String baseUrl = 'https://tu-servicio.onrender.com';  // API Dart
```

Compila para Android/iOS y publica en stores.

---

## 4. Checklist pre-despliegue

- [ ] `api/config/database.php` con credenciales correctas
- [ ] Base de datos creada con `database/minuto_a_minuto_schema.sql`
- [ ] `ADMIN_USER` y `ADMIN_PASS` en variables de entorno (producción)
- [ ] Probar login en `/admin/`
- [ ] Probar endpoint `/api/test` para verificar conexión DB

---

## 5. Seguridad recomendada

- Usar **HTTPS** en producción
- No subir `api/config/database.php` con credenciales reales a repos públicos
- Usar variables de entorno o archivo fuera del webroot para credenciales
- Cambiar credenciales por defecto del portal admin
