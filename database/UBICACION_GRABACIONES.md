# Ubicación de las grabaciones de llamadas

## Tabla `registro_llamadas`

La tabla incluye dos campos para evidencia de la llamada:

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `rutaGrabacion` | TEXT | Ruta o URL del archivo de audio de la grabación |
| `transcripcionTexto` | TEXT | Texto transcrito (IA Speech-to-Text) |

## Dónde se guarda la grabación

### Opción 1: Almacenamiento local en el dispositivo (app actual)

- **Ruta típica**: 
  - Android: `getApplicationDocumentsDirectory()/grabaciones_llamadas/`
  - iOS: `NSSearchPathForDirectoriesInDomains(NSDocumentDirectory)`
- **Ejemplo de ruta guardada en BD**: 
  ```
  /data/user/0/com.minutoaminuto.app/files/grabaciones_llamadas/llamada_abc123_20250219.mp3
  ```

### Opción 2: Servidor/SharePoint (recomendado para trazabilidad)

- Subir el archivo a una biblioteca de documentos (SharePoint, OneDrive, S3, etc.)
- Guardar en `rutaGrabacion` la URL completa:
  ```
  https://empresa.sharepoint.com/sites/Ventas/GrabacionesLlamadas/llamada_abc123.mp3
  ```

### Opción 3: Blob Storage / Base de datos

- Guardar el archivo como BLOB en la misma BD o en Azure Blob Storage
- En `rutaGrabacion` guardar el identificador o la URL del blob

## Implementación futura en la app

Para agregar grabación real, se necesitaría:

1. **Permiso de micrófono** en `AndroidManifest.xml` e `Info.plist`
2. **Paquete**: `record` o `flutter_sound` para grabar audio
3. **Flujo**:
   - Usuario pulsa "Iniciar llamada" → inicia grabación
   - Usuario pulsa "Finalizar" → detiene y guarda
   - Ruta se guarda en `registro_llamadas.rutaGrabacion`
