@echo off
echo Iniciando API Minuto a Minuto...
echo (Si el puerto 8080 esta en uso, se usara 8081 automaticamente)
cd api_server
start "API Server" cmd /k "dart run bin/server.dart"
cd ..
timeout /t 3 /nobreak >nul
echo Iniciando app en Chrome...
echo IMPORTANTE: Si la API usa puerto 8081, actualice baseUrl en lib/config/api_config.dart
flutter run -d chrome
