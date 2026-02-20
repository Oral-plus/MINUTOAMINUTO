@echo off
REM Genera el keystore para firmar la app en Google Play
cd /d "%~dp0..\android"

echo Creando upload-keystore.jks...
echo.
echo IMPORTANTE: Guarda la contrasena y el alias (upload) en un lugar seguro.
echo La perderas = no podras actualizar la app en Google Play.
echo.

keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

if errorlevel 1 (
    echo ERROR: keytool no encontrado. Asegurate de tener Java JDK instalado.
    exit /b 1
)

echo.
echo Keystore creado: android\upload-keystore.jks
echo.
echo Siguiente paso: crea android\key.properties con:
echo   storePassword=TU_PASSWORD
echo   keyPassword=TU_PASSWORD
echo   keyAlias=upload
echo   storeFile=upload-keystore.jks
echo.
pause
