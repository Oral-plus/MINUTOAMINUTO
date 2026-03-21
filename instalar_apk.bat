@echo off
chcp 65001 >nul
echo ========================================
echo  Instalador APK - Minuto a Minuto
echo ========================================
echo.

set APK=build\app\outputs\flutter-apk\app-release.apk

if not exist "%APK%" (
    echo APK no encontrado. Construyendo...
    call .\flutter\bin\flutter.bat build apk --release
    if errorlevel 1 (
        echo Error al construir.
        pause
        exit /b 1
    )
)

echo Conecta el celular por USB con depuración USB activada.
echo Luego ejecuta: adb devices
echo.
echo Desinstalando versión anterior (si existe)...
adb uninstall com.minutoaminuto.minuto_a_minuto 2>nul

echo.
echo Instalando APK...
adb install -r "%APK%"

if errorlevel 1 (
    echo.
    echo --- SI FALLO: ---
    echo 1. Desinstala Minuto a Minuto manualmente del celular
    echo 2. Activa "Instalar apps desconocidas" para el explorador de archivos
    echo 3. Copia el APK al celular por USB (no uses WhatsApp)
    echo 4. Instala desde el explorador de archivos del celular
    echo.
    echo Ruta del APK: %cd%\%APK%
) else (
    echo.
    echo Instalación exitosa.
)

echo.
pause
