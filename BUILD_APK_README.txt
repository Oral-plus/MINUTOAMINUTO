========================================
  CÓMO GENERAR EL APK (si hay errores de archivo bloqueado)
========================================

1. EJECUTAR EL SCRIPT:
   scripts\build_apk.bat

2. SI SIGUE FALLANDO, probar en este orden:

   a) Pausar OneDrive (clic derecho en el icono de OneDrive > Pausar sincronización)
      - El Escritorio suele estar sincronizado con OneDrive
      - OneDrive puede bloquear archivos mientras se compilan

   b) Excluir la carpeta del antivirus:
      - Windows Defender > Protección contra virus > Exclusiones
      - Agregar: C:\Users\[tu_usuario]\Desktop\MINUTOAMINUTO

   c) Mover el proyecto a una carpeta no sincronizada:
      - Ejemplo: C:\proyectos\MINUTOAMINUTO
      - Copiar todo el proyecto ahí y compilar desde esa ubicación

   d) Reiniciar el PC y volver a intentar (libera todos los bloqueos)

3. El APK se genera en:
   build\app\outputs\flutter-apk\app-release.apk
