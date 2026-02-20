# Desplegar API en Render

## Pasos

1. **Sube el código a GitHub** (o GitLab/Bitbucket).

2. **Entra a [render.com](https://render.com)** e inicia sesión.

3. **Nuevo Web Service**
   - Dashboard → New → Web Service
   - Conecta tu repositorio
   - Selecciona el repo de Minuto a Minuto

4. **Configuración**
   - **Name:** api-minuto-a-minuto (o el que prefieras)
   - **Root Directory:** `api_server` (obligatorio)
   - **Runtime:** Docker
   - **Region:** Elige la más cercana

5. **Deploy**
   - Clic en Create Web Service
   - Render construirá la imagen y desplegará

6. **URL de la API**
   - Al finalizar: `https://api-minuto-a-minuto.onrender.com`
   - Endpoint de prueba: `https://tu-servicio.onrender.com/test`

## Configurar la app Flutter

En `lib/config/api_config.dart`:

```dart
static const String baseUrl = 'https://TU-SERVICIO.onrender.com';
```

Reemplaza `TU-SERVICIO` por el nombre que pusiste en Render.

## Plan gratuito

- El servicio se duerme tras ~15 min sin uso
- La primera petición tras dormir puede tardar 30–60 s en responder
- Para producción continua, considera un plan de pago
