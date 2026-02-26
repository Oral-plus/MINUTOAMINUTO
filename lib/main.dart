import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show FlutterError, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'utils/constants.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'widgets/monitor_floating_bubble.dart';
import 'widgets/splash_screen.dart';

// Inicializa SQLite FFI en Windows/Desktop (no en Web)
import 'utils/init_db_ffi.dart'
    if (dart.library.html) 'utils/init_db_stub.dart'
    as db_init;

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MonitorFloatingBubble(),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No rethrow: evita que cualquier error de Flutter cierre la app.
  FlutterError.onError = (details) {
    debugPrint('FlutterError: ${details.exception}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher.onError: $error\n$stack');
    return true; // true = error manejado, la app no se cierra
  };
  ErrorWidget.builder = (details) => Material(
    color: Colors.white,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange[700]),
            const SizedBox(height: 16),
            Text(
              'Error de visualización',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Reinicia la app',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    ),
  );
  runZonedGuarded(() async {
    try {
      if (!kIsWeb) db_init.initDatabase();
    } catch (_) {}
    runApp(const MinutoAMinutoApp());
  }, (error, stack) {
    debugPrint('runZonedGuarded: $error\n$stack');
  });
}

class MinutoAMinutoApp extends StatefulWidget {
  const MinutoAMinutoApp({super.key});

  @override
  State<MinutoAMinutoApp> createState() => _MinutoAMinutoAppState();
}

class _MinutoAMinutoAppState extends State<MinutoAMinutoApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = ChangeNotifierProvider(
        create: (_) {
          final provider = AppProvider();
          provider.init().catchError((e, st) {
            debugPrint('AppProvider.init error: $e $st');
          });
          return provider;
        },
        child: MaterialApp(
          navigatorKey: AppKeys.navigatorKey,
          scaffoldMessengerKey: AppKeys.scaffoldMessengerKey,
          title: 'Minuto a Minuto',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppConstants.azulCorporativo,
              primary: AppConstants.azulCorporativo,
              secondary: AppConstants.verdeMeta,
              error: AppConstants.rojoCritico,
              surface: Colors.white,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 4,
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF1F2937),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
              ),
            ),
            textTheme: TextTheme(
              headlineSmall: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.25,
              ),
              titleMedium: const TextStyle(fontWeight: FontWeight.w600),
              bodyLarge: TextStyle(color: Colors.grey.shade800),
            ),
          ),
          home: Consumer<AppProvider>(
            builder: (context, provider, _) {
              if (!provider.isInitialized) {
                return const SplashScreen();
              }
              if (provider.initError != null) {
                return Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            provider.initError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              if (provider.usuarioActual != null ||
                  provider.vendedorActual != null) {
                return const HomeScreen();
              }
              return const LoginScreen();
            },
          ),
        ),
    );
    // Sin WithForegroundTask para evitar bloqueos frecuentes; el servicio se inicia al activar.
    return child;
  }
}
