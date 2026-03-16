@echo off
chcp 65001 >nul
title MINUTO A MINUTO - Configurador de Celular
set ADB="%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
set PKG=com.minutoaminuto.minuto_a_minuto

echo ═══════════════════════════════════════════════════════════════
echo          MINUTO A MINUTO - CONFIGURADOR DE CELULAR
echo ═══════════════════════════════════════════════════════════════
echo.
echo  Este script configura el celular del empleado para que la
echo  app funcione al 100%% sin pedir permisos.
echo.
echo  REQUISITOS:
echo   1. El celular debe estar conectado por USB
echo   2. Depuracion USB debe estar activada
echo   3. Aceptar "Confiar en este equipo" en el celular
echo.
echo ═══════════════════════════════════════════════════════════════
echo.
pause

echo.
echo [1/8] Verificando conexion...
%ADB% devices | findstr /r /c:"device$" >nul
if %errorlevel% neq 0 (
    echo *** ERROR: No se detecto ningun celular conectado.
    echo     Verifica el cable USB y que la Depuracion USB este activa.
    pause
    exit /b 1
)
echo       OK - Celular detectado

echo.
echo [2/8] Instalando la app...
%ADB% install -r -g "%~dp0build\app\outputs\flutter-apk\app-release.apk"
echo       OK - App instalada

echo.
echo [3/9] Otorgando TODOS los permisos de la app...
%ADB% shell pm grant %PKG% android.permission.RECORD_AUDIO
%ADB% shell pm grant %PKG% android.permission.READ_PHONE_STATE
%ADB% shell pm grant %PKG% android.permission.READ_CALL_LOG
%ADB% shell pm grant %PKG% android.permission.READ_PHONE_NUMBERS
%ADB% shell pm grant %PKG% android.permission.ACCESS_FINE_LOCATION
%ADB% shell pm grant %PKG% android.permission.ACCESS_COARSE_LOCATION
%ADB% shell pm grant %PKG% android.permission.POST_NOTIFICATIONS
%ADB% shell pm grant %PKG% android.permission.SYSTEM_ALERT_WINDOW
echo       OK - Permisos concedidos

echo.
echo [4/9] Desbloqueando Configuracion Restringida (Android 13+)...
echo       SI EN LA APP DE ACCESIBILIDAD APARECE "CONFIGURACION RESTRINGIDA":
echo       1. Se abrira la info de la app en un momento.
echo       2. Toca los 3 puntos arriba a la derecha.
echo       3. Toca "Permitir configuracion restringida".
%ADB% shell am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:%PKG%
timeout /t 5 >nul
echo       OK - Pantalla abierta

echo.
echo [5/9] Forzando permisos de operacion de audio (CAPTURE_AUDIO_OUTPUT)...
%ADB% shell appops set %PKG% RECORD_AUDIO allow
%ADB% shell appops set %PKG% PROJECT_MEDIA allow
%ADB% shell appops set %PKG% PHONE_CALL_MICROPHONE allow
%ADB% shell appops set %PKG% PHONE_CALL_CAMERA allow
echo       OK - Operaciones de audio forzadas

echo.
echo [6/9] Habilitando el Servicio de Accesibilidad...
%ADB% shell settings put secure enabled_accessibility_services %PKG%/.CallRecordAccessibilityService
%ADB% shell settings put secure accessibility_enabled 1
echo       OK - Servicio de accesibilidad habilitado

echo.
echo [7/9] Otorgando permiso de superposicion (overlay)...
%ADB% shell appops set %PKG% SYSTEM_ALERT_WINDOW allow
echo       OK - Superposicion habilitada

echo.
echo [8/9] Deshabilitando optimizacion de bateria para la app...
%ADB% shell dumpsys deviceidle whitelist +%PKG%
%ADB% shell cmd appops set %PKG% RUN_IN_BACKGROUND allow
%ADB% shell cmd appops set %PKG% RUN_ANY_IN_BACKGROUND allow
echo       OK - App excluida de ahorro de bateria

echo.
echo [9/9] Configurando audio del sistema para grabacion...
%ADB% shell settings put system volume_voice 5
echo       OK - Volumen de llamada configurado

echo.
echo ═══════════════════════════════════════════════════════════════
echo.
echo  CONFIGURACION COMPLETA!
echo.
echo  El celular esta listo. La app ya tiene:
echo   - Todos los permisos concedidos
echo   - Accesibilidad habilitada
echo   - Superposicion habilitada
echo   - Optimizacion de bateria desactivada
echo   - Permisos de audio forzados
echo.
echo  Ya puedes desconectar el celular.
echo.
echo ═══════════════════════════════════════════════════════════════
pause
