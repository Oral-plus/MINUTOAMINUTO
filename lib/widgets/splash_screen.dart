import 'dart:async';
import 'package:flutter/material.dart';

/// Pantalla de carga: logo completo (sin círculo), animación de puntos.
/// Timeout de seguridad: si tarda más de 5s, muestra botón para reintentar.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  Timer? _timeoutTimer;
  bool _showTimeout = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();

    // Si después de 6s sigue en splash, mostrar mensaje de espera
    _timeoutTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _showTimeout = true);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo completo sin recorte circular
                Image.asset(
                  'assets/images/logo.png',
                  height: 120,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                const SizedBox(height: 32),
                // Barra de progreso indeterminada
                SizedBox(
                  width: 180,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF1565C0),
                    ),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _showTimeout ? 'Iniciando...' : 'Cargando',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
