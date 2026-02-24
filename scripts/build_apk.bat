@echo off
cd /d "%~dp0.."

echo ========================================
echo  BUILD APK - Evitando bloqueos Windows
echo ========================================
echo.

echo [1/4] Cerrando todos los procesos Java...
taskkill /F /IM java.exe 2>nul
taskkill /F /IM javaw.exe 2>nul
timeout /t 2 /nobreak >nul

echo [2/4] Deteniendo Gradle daemon...
call android\gradlew.bat --stop 2>nul
timeout /t 2 /nobreak >nul

echo [3/4] Eliminando carpetas build...
if exist "build" (
    rmdir /s /q "build" 2>nul
    if exist "build" (
        echo    Reintentando eliminar build en 2 seg...
        timeout /t 2 /nobreak >nul
        rmdir /s /q "build" 2>nul
    )
)

echo [4/4] Limpiando y compilando...
call flutter clean
call flutter pub get
call flutter build apk --release --no-build-cache

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo  APK generado correctamente
    echo  build\app\outputs\flutter-apk\app-release.apk
    echo ========================================
) else (
    echo.
    echo ERROR: Si sigue fallando, prueba:
    echo - Pausar OneDrive temporalmente
    echo - Excluir esta carpeta del antivirus
    echo - Mover el proyecto a C:\proyectos\MINUTOAMINUTO
    echo - Reiniciar el PC y volver a intentar
)
echo.
pause
