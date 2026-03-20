@echo off
color 0A
title Instalador Extremo - Minuto a Minuto (Samsung Bypass)
echo =======================================================
echo    MINUTO A MINUTO - AUTO CONFIGURADOR BURLA SEGURIDAD   
echo =======================================================
echo.
echo Conecta el celular de la empresa por cable USB.
echo Asegurate de darle "Permitir Depuracion USB" en la pantalla del celular.
echo.
pause

echo.
echo Instalando App...
adb install -r build\app\outputs\flutter-apk\app-release.apk

echo.
echo Forzando Activacion de Grabadora Nativa Oculta de Samsung...
adb shell settings put global call_recording_auto_enable 1
adb shell settings put system call_recording_auto_enable 1
adb shell settings put global ptt_call_record_on 1
adb shell settings put system ptt_call_record_on 1
adb shell settings put global call_recording 1
adb shell settings put system call_recording 1

echo.
echo Inyectando Permisos de Administrador Extremos a Minuto a Minuto...
adb shell appops set com.minutoaminuto.minuto_a_minuto PROJECT_MEDIA allow
adb shell appops set com.minutoaminuto.minuto_a_minuto SYSTEM_ALERT_WINDOW allow
adb shell dumpsys deviceidle whitelist +com.minutoaminuto.minuto_a_minuto

echo.
echo Abriendo la aplicacion...
adb shell am start -n com.minutoaminuto.minuto_a_minuto/com.minutoaminuto.minuto_a_minuto.MainActivity

echo.
echo =======================================================
echo TODO LISTO. LA APLICACION AHORA TIENE PODERES DE SISTEMA.
echo Ya puedes desconectar el celular.
echo =======================================================
pause
