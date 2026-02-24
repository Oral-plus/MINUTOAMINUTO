@echo off
echo Cerrando procesos Gradle...
cd /d "%~dp0.."
call android\gradlew.bat --stop 2>nul
echo.
echo Eliminando carpeta build conflictiva...
if exist "build\app\intermediates\dex" rmdir /s /q "build\app\intermediates\dex" 2>nul
echo.
echo Limpiando proyecto...
call flutter clean
echo.
echo Compilando APK (sin daemon para evitar bloqueos)...
call flutter build apk --release
pause
