import '../utils/app_theme.dart';
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show FlutterError, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
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
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        debugPrint('FlutterError: ${details.exception}\n${details.stack}');
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('PlatformDispatcher.onError: $error\n$stack');
        return true; // Evita que el error crashee la app
      };
      runApp(const MinutoAMinutoApp());
      _initPersistenceEarly();
    },
    (error, stack) {
      debugPrint('runZonedGuarded FATAL: $error\n$stack');
      // Aseguramos que el usuario vea algo si esto sucede antes de MaterialApp
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error Crítico de Inicio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(error.toString(), textAlign: TextAlign.center),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => main(),
                    child: Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
    },
  );
}

/// Inicialización de persistencia base
Future<void> _initPersistenceEarly() async {
  try {
    if (!kIsWeb) db_init.initDatabase();
  } catch (_) {}
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
        child: Consumer<AppProvider>(
          builder: (ctx, provider, child) => MaterialApp(
          navigatorKey: AppKeys.navigatorKey,
          scaffoldMessengerKey: AppKeys.scaffoldMessengerKey,
          title: 'Minuto a Minuto',
          debugShowCheckedModeBanner: false,
          themeMode: provider.themeMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          // El overlay de guardado va aquí: dentro de MaterialApp, con Directionality garantizada
          builder: (context, child) {
            // Interceptar el botón de atrás para minimizar en lugar de cerrar
            // Esto evita que la app se cierre al colgar una llamada
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop) {
                  // En Android minimiza, en Windows cerramos solo si es intencional
                  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
                    SystemNavigator.pop(animated: true);
                  } else {
                    // En Windows u otros, el botón atrás no debería cerrar la app
                    // a menos que estemos en una ruta profunda, pero aquí es el root
                    debugPrint('PopScope: Bloqueado cierre en plataforma no-Android');
                  }
                }
              },
              child: _CallSavingOverlayWrapper(
              child: child ?? const SizedBox.shrink(),
              onCallSaved: () {
                try {
                  context.read<AppProvider>().cargarDatosHoy();
                } catch (_) {}
              },
            ),
            );
          },
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
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 80,
                            color: context.ac.fg.withOpacity(0.26),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'No se pudo conectar',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                          SizedBox(height: 12),
                          Text(
                            provider.initError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                          SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => provider.init(force: true),
                              icon: Icon(Icons.refresh_rounded),
                              label: Text('Reintentar Conexión'),
                            ),
                          ),
                          SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('¿Limpiar datos locales?'),
                                  content: Text('Esto cerrará tu sesión y borrará el caché para solucionar problemas persistentes.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Limpiar')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await provider.forceClearCache();
                                provider.init(force: true);
                              }
                            },
                            icon: Icon(Icons.delete_sweep_outlined, size: 18),
                            label: Text('Limpiar Caché y Reiniciar'),
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
        ),
    );
    return child;
  }
}

/// Wrapper interno del overlay de guardado — vive dentro de MaterialApp
/// para tener Directionality y MediaQuery disponibles.
class _CallSavingOverlayWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onCallSaved;
  const _CallSavingOverlayWrapper({required this.child, this.onCallSaved});

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
      if (p.stage == SavingStage.listo) {
        widget.onCallSaved?.call();
      }
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
