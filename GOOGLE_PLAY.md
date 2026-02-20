# Publicar Minuto a Minuto en Google Play

## 1. Crear keystore (solo la primera vez)

**IMPORTANTE:** Guarda el keystore y la contraseña en un lugar seguro. Si los pierdes, no podrás actualizar la app en Google Play.

```bash
cd android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

O ejecuta: `scripts\create_keystore.bat`

Completa los datos que solicita (nombre, organización, etc.). La contraseña la elegirás tú.

## 2. Configurar key.properties

En `android/key.properties` (crear si no existe):

```properties
storePassword=TU_PASSWORD_KEYSTORE
keyPassword=TU_PASSWORD_KEY
keyAlias=upload
storeFile=upload-keystore.jks
```

Este archivo **NO** se sube a git (está en .gitignore).

## 3. Generar APK y AAB

```bash
flutter pub get
flutter build apk --release      # APK para instalación directa
flutter build appbundle --release # AAB para Google Play (recomendado)
```

O ejecuta: `scripts\build_release.bat`

**Salida:**
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

## 4. Crear app en Google Play Console

1. Ve a [Google Play Console](https://play.google.com/console)
2. Crear aplicación → Nombre: **Minuto a Minuto**
3. Completa: descripción, capturas de pantalla, icono, política de privacidad (si aplica)

## 5. Subir el AAB

1. En Play Console → Tu app → Producción (o Prueba interna)
2. Crear nueva versión
3. Sube `app-release.aab`
4. Completa las notas de la versión
5. Revisar y publicar

## Requisitos Google Play

- **AAB** (App Bundle) es obligatorio para apps nuevas
- **minSdk 21** o superior ✓
- **targetSdk 34** (2024) ✓
- Firma con tu propio keystore ✓

## Build sin keystore

Si ejecutas `flutter build apk` o `flutter build appbundle` sin `key.properties`, se usará la firma de debug. Eso funciona para probar, pero **Google Play rechazará** esa versión. Debes firmar con tu keystore de producción.
