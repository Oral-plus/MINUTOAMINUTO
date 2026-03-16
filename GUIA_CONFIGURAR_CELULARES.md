# Guía: Configurar Celulares de Empleados

## Paso 1: Activar Opciones de Desarrollador en el celular

1. Ir a **Ajustes** > **Acerca del teléfono**
2. Buscar **"Número de compilación"** (en Samsung está en Ajustes > Acerca > Info del software)
3. **Tocar 7 veces seguidas** en "Número de compilación"
4. Aparecerá un mensaje: *"Ya eres desarrollador"*

## Paso 2: Activar Depuración USB

1. Ir a **Ajustes** > **Opciones de desarrollador**
2. Activar **"Depuración USB"**
3. Aceptar el aviso de seguridad

## Paso 3: Conectar el celular al computador

1. Conectar el celular por **cable USB**
2. En el celular aparecerá: **"¿Permitir depuración USB?"**
3. Marcar **"Siempre permitir desde este equipo"** y aceptar

## Paso 4: Desbloquear "Configuración restringida" (Android 13 o superior)

Si al intentar activar Accesibilidad te dice que la configuración es **restringida**:
1. Ve a **Ajustes** > **Aplicaciones** > **Minuto a Minuto**
2. Toca los **3 puntos** arriba a la derecha (o el botón "Más")
3. Selecciona **"Permitir configuración restringida"**
4. Confirma con tu huella o PIN
5. Ahora vuelve a Accesibilidad y ya te dejará activarlo.

## Paso 5: Ejecutar el configurador

1. En el computador, ir a la carpeta del proyecto
2. Hacer **doble clic** en **`CONFIGURAR_CELULAR.bat`**
3. Seguir las instrucciones en pantalla
4. El script instalará la app y otorgará TODOS los permisos automáticamente

## ¿Qué hace el script?

| Acción | Efecto |
|--------|--------|
| Instala la APK | No necesitas enviar el archivo al celular |
| Otorga permisos | Micrófono, ubicación, teléfono, notificaciones |
| Fuerza permisos de audio | Habilita captura de audio durante llamadas |
| Activa Accesibilidad | Habilita el servicio de monitoreo |
| Activa Superposición | Habilita el icono flotante de grabación |
| Desactiva ahorro de batería | La app nunca se cierra en segundo plano |

## Resultado

Después de ejecutar el script, el empleado:
- **NO verá** ventanas pidiendo permisos
- La app **grabará automáticamente** todas las llamadas
- El **icono flotante** aparecerá durante las llamadas
- La app **nunca se cerrará** por ahorro de batería
