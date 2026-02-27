import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show FlutterError, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'services/call_monitor_service.dart';
import 'utils/constants.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/call_saving_progress_service.dart';
import 'widgets/call_saving_overlay.dart';
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

void main() {
  // main() NO es async — evita bloquear el hilo principal antes del primer frame
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    debugPrint('FlutterError: ${details.exception}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher.onError: $error');
    return true;
  };

  // Arrancar la UI de inmediato — sin await, sin trabajo pesado aquí
  runZonedGuarded(
    () {
      runApp(const MinutoAMinutoApp());
    },
    (error, stack) {
      debugPrint('runZonedGuarded: $error');
    },
  );

  // Todo el trabajo pesado va DESPUÉS del primer frame, en microtasks
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initBackground();
  });
}

/// Inicialización pesada — corre después del primer frame visible
Future<void> _initBackground() async {
  try {
    FlutterForegroundTask.initCommunicationPort();
  } catch (_) {}
  try {
    if (!kIsWeb) db_init.initDatabase();
  } catch (_) {}
  // Monitor de llamadas con delay adicional para no saturar el arranque
  await Future.delayed(const Duration(seconds: 3));
  try {
    if (!kIsWeb) {
      await CallMonitorService.init().timeout(
        const Duration(seconds: 10),
        onTimeout: () => debugPrint('CallMonitor.init timeout'),
      );
    }
  } catch (e) {
    debugPrint('CallMonitor.init error: $e');
  }
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
          // El overlay de guardado va aquí: dentro de MaterialApp, con Directionality garantizada
          builder: (context, child) {
            // Interceptar el botón de atrás para minimizar en lugar de cerrar
            // Esto evita que la app se cierre al colgar una llamada
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop) {
                  // Minimizar la app en lugar de cerrarla
                  SystemNavigator.pop(animated: true);
                }
              },
              child: _CallSavingOverlayWrapper(child: child ?? const SizedBox.shrink()),
            );
          },
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
    return child;
  }
}

/// Wrapper interno del overlay de guardado — vive dentro de MaterialApp
/// para tener Directionality y MediaQuery disponibles.
class _CallSavingOverlayWrapper extends StatefulWidget {
  final Widget child;
  const _CallSavingOverlayWrapper({required this.child});

  @override
  State<_CallSavingOverlayWrapper> createState() =>
      _CallSavingOverlayWrapperState();
}

class _CallSavingOverlayWrapperState extends State<_CallSavingOverlayWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _slideAnim;
  StreamSubscription<CallSavingProgress>? _sub;
  CallSavingProgress _progress = CallSavingProgressService.current;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    _sub = CallSavingProgressService.stream.listen((p) {
      if (!mounted) return;
      setState(() => _progress = p);
      if (p.isActive) {
        _animCtrl.forward();
      } else if (p.isDone) {
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) _animCtrl.reverse();
        });
      } else {
        _animCtrl.reverse();
      }
    });

    if (_progress.isActive) _animCtrl.forward();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(_slideAnim),
            child: SavingBanner(progress: _progress),
          ),
        ),
      ],
    );
  }
}
