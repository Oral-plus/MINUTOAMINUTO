import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'utils/constants.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'widgets/splash_screen.dart';

// Inicializa SQLite FFI en Windows/Desktop (no en Web)
import 'utils/init_db_ffi.dart' if (dart.library.html) 'utils/init_db_stub.dart' as db_init;
import 'services/call_monitor_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  db_init.initDatabase();
  if (Platform.isAndroid) {
    FlutterForegroundTask.initCommunicationPort();
    await CallMonitorService.init();
  }
  runApp(const MinutoAMinutoApp());
}

class MinutoAMinutoApp extends StatelessWidget {
  const MinutoAMinutoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: ChangeNotifierProvider(
        create: (_) => AppProvider()..init(),
        child: MaterialApp(
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
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 4,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 1,
            ),
          ),
          textTheme: TextTheme(
            headlineSmall: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.25),
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
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
            if (provider.supervisores.isEmpty && provider.vendedores.isEmpty) {
              return const SetupScreen();
            }
            return const LoginScreen();
          },
        ),
      ),
    ),
    );
  }
}
