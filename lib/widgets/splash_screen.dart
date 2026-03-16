import 'dart:async';
import 'package:flutter/material.dart';

/// Splash screen premium — fondo negro, logo centrado con glow, barra de progreso elegante.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  Timer? _timeoutTimer;
  bool _showTimeout = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();

    _timeoutTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _showTimeout = true);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Oral-Plus logo directo sobre fondo oscuro ─────────
                Image.asset(
                  'assets/images/LOGO 2 1 (2).png',
                  width: 240,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/LLAMADA.png',
                    width: 200,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 28),
                // App name
                const Text(
                  'MINUTO A MINUTO',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'SEGUIMIENTO · PPVC · RVC',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.3),
                    letterSpacing: 3.5,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white54),
                      minHeight: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _showTimeout ? 'Iniciando servicios...' : 'Cargando',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.2),
                    letterSpacing: 1,
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
