@echo off
REM Genera APK y AAB para Google Play - Minuto a Minuto
echo ========================================
echo  Minuto a Minuto - Build Release
echo ========================================
echo.

cd /d "%~dp0.."

REM Verificar Flutter
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Flutter no encontrado. Instala Flutter y anade al PATH.
    exit /b 1
)

REM Limpiar y obtener dependencias
echo [1/4] Obteniendo dependencias...
call flutter pub get
if errorlevel 1 exit /b 1

echo.
echo [2/4] Generando APK (release)...
call flutter build apk --release
if errorlevel 1 (
    echo.
    echo Si falla por firma: crea android/key.properties y android/upload-keystore.jks
    echo Ver GOOGLE_PLAY.md para instrucciones.
    exit /b 1
)

echo.
echo [3/4] Generando AAB para Google Play...
call flutter build appbundle --release
if errorlevel 1 exit /b 1

echo.
echo [4/4] Completado.
echo.
echo APK:  build\app\outputs\flutter-apk\app-release.apk
echo AAB:  build\app\outputs\bundle\release\app-release.aab
echo.
echo Sube el AAB a Google Play Console para publicar.
echo.
pause
