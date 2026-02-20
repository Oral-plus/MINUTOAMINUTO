# Ejecutar Minuto a Minuto en Web (Chrome)

## Opción 1: Doble clic (más simple)

1. Ejecuta **`start_web.bat`** (doble clic)
2. Se abrirá la API y luego la app en Chrome

## Opción 2: Desde Cursor/VS Code

1. Abre **Run and Debug** (Ctrl+Shift+D)
2. Selecciona **"Minuto a Minuto (Web)"**
3. Presiona F5

La API se inicia sola y luego se abre la app en Chrome.

## Opción 3: Manual (2 terminales)

**Terminal 1 – API:**
```bash
cd api_server
dart run bin/server.dart
```

**Terminal 2 – App:**
```bash
flutter run -d chrome
```

---

La app usa `useRemoteApi = true` y se conecta a `http://localhost:8080`.
