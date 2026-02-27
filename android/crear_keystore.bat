@echo off
echo Creando keystore para firma de release...
echo.
cd /d "%~dp0"

if exist "app\upload-keystore.jks" (
    echo YA EXISTE app\upload-keystore.jks
    echo Si quieres crear uno nuevo, borra el archivo actual primero.
    pause
    exit /b 0
)

keytool -genkey -v -keystore app\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

if %errorlevel% neq 0 (
    echo Error al crear el keystore. Asegurate de tener Java instalado.
    pause
    exit /b 1
)

echo.
echo Keystore creado en app\upload-keystore.jks
echo.
echo Crea key.properties en esta carpeta con:
echo storePassword=TU_PASSWORD
echo keyPassword=TU_PASSWORD
echo keyAlias=upload
echo storeFile=app/upload-keystore.jks
echo.
pause
