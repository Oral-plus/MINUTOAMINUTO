# Minuto a Minuto - App Flutter

Sistema de seguimiento comercial PPVC y RVC según el marco estratégico "Minuto a Minuto".

## Objetivos del proceso
- Aumentar cobertura
- Mejorar satisfacción
- Incrementar ventas
- Optimizar recursos
- Facilitar toma de decisiones

## Características implementadas

### A. Herramientas tecnológicas base
- ✅ **Dashboard Minuto a Minuto** con 6 bloques:
  1. **Disciplina Operativa** - % llamadas coach, inicio jornada, geolocalización, semáforo automático
  2. **Productividad del día** - Venta, recaudo, presupuesto, ticket promedio
  3. **Ejecución PPVC vs RVC** - Coincidencia programado vs visitado
  4. **Control jerárquico** - Coach, KAM, Jefe
  5. **Alertas críticas** - Lista priorizada
  6. **Ranking diario** - Top 5 y Bottom 5 vendedores

### B. Registro digital de llamadas obligatorio
- Formulario con todos los campos requeridos
- Fecha, hora, supervisor, vendedor, duración, tipo (mañana/tarde/KAM/Jefe)
- Clientes programados/visitados, venta, recaudo, meta, PPVC-RVC
- Confirmación de veracidad obligatoria
- Duración mínima 2 minutos

### C. Sistema de evidencia
- Geolocalización en ruta (activar/desactivar)
- Registro de ubicaciones en base de datos

### D. Semáforo automático diario
- 🟢 Cumple llamadas (≥90%)
- 🟡 Cumple 1 de 2 (80-89%)
- 🔴 No cumple (<80%)

### E. Estructura de speech de llamadas
- Llamada mañana: Planeación y enfoque
- Llamada tarde: Control y cierre
- Llamada KAM y Jefe: Enfoque estratégico

### F. Jerarquía configurada
- 50 vendedores
- 7 coaches (~7 vendedores por coach)
- 1 KAM
- 1 Jefe de Ventas

## Cómo ejecutar

```bash
# Obtener dependencias
flutter pub get

# Ejecutar (seleccione el dispositivo disponible)
flutter run
```

**Plataformas soportadas:**
- **Android/iOS**: Completamente funcional (recomendado)
- **Windows**: Requiere Visual Studio con workload "Desktop development with C++"
- **Web**: No soportada (sqflite no funciona en navegador)

## Estructura del proyecto

```
lib/
├── main.dart              # Punto de entrada
├── models/                # Vendedor, Supervisor, RegistroLlamada, PPVC, RVC, Alerta
├── providers/             # AppProvider (estado global)
├── screens/               # Login, Home, NuevaLlamada, MisLlamadas, Dashboard, Speech
├── services/              # DatabaseService, LocationService, AlertasService
├── utils/                 # Constants, KpiCalculator, SeedData
└── widgets/               # BloqueDisciplina, Productividad, PPvcRvc, etc.
```

## Datos de prueba

Al primera ejecución se cargan automáticamente:
- 1 Jefe, 1 KAM, 7 Coaches
- 50 vendedores asignados
- PPVC y RVC de hoy para 10 vendedores

Seleccione cualquier usuario en el login para probar.

## Integración futura

Para conectar con SharePoint/Power BI:
1. Reemplazar `DatabaseService` por cliente REST a SharePoint/Power Automate
2. Los modelos ya están preparados con `toMap()`/`fromMap()`
3. Power BI puede consumir datos vía API o exportación periódica
# MINUTOAMINUTO
