import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Splash screen premium — fondo negro total, logo con glow + animaciones
/// secuenciales (logo → línea → texto → subtítulo → barra).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _lineCtrl;
  late AnimationController _textCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _progressCtrl;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _lineWidth;
  late Animation<double> _textFade;
  late Animation<double> _textSlide;
  late Animation<double> _glowPulse;

  bool _showTimeout = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();

    // Logo: fade + scale
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _logoFade  = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic));

    // Línea horizontal que crece desde el centro
    _lineCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _lineWidth = CurvedAnimation(parent: _lineCtrl, curve: Curves.easeOut);

    // Texto + subtítulo: fade + slide up
    _textCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _textFade  = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide = Tween<double>(begin: 14, end: 0)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    // Glow pulsante bajo el logo
    _glowCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _glowPulse = Tween<double>(begin: 0.25, end: 0.55)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // Progress dots
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

    // Secuencia de animaciones
    _runSequence();

    _timeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _showTimeout = true);
    });
  }

  Future<void> _runSequence() async {
    await _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    await _lineCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 80));
    await _textCtrl.forward();
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _lineCtrl.dispose();
    _textCtrl.dispose();
    _glowCtrl.dispose();
    _progressCtrl.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // Fondo: viñeta radial muy sutil
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    const Color(0xFF0E0E0E),
                    const Color(0xFF050505),
                  ],
                ),
              ),
            ),
          ),

          // Contenido centrado
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glow + Logo
                AnimatedBuilder(
                  animation: Listenable.merge([_logoCtrl, _glowCtrl]),
                  builder: (context, _) => FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow aura
                          Container(
                            width: 280,
                            height: 140,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(80),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(_glowPulse.value * 0.12),
                                  blurRadius: 80,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          // Logo
                          Image.asset(
                            'assets/images/LOGO 2 1 (2).png',
                            width: 260,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, _, _) => Image.asset(
                              'assets/images/LLAMADA.png',
                              width: 120,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Línea separadora animada
                AnimatedBuilder(
                  animation: _lineCtrl,
                  builder: (context, _) => SizedBox(
                    width: 220,
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: _lineWidth.value * 220,
                        height: 0.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Nombre + subtítulo animados
                AnimatedBuilder(
                  animation: _textCtrl,
                  builder: (context, _) => FadeTransition(
                    opacity: _textFade,
                    child: Transform.translate(
                      offset: Offset(0, _textSlide.value),
                      child: Column(
                        children: [
                          const Text(
                            'MINUTO A MINUTO',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ORAL · PLUS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.28),
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 56),

                // Indicador de carga: tres puntos pulsantes
                AnimatedBuilder(
                  animation: _progressCtrl,
                  builder: (context, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        final phase = (_progressCtrl.value - i * 0.18).clamp(0.0, 1.0);
                        final pulse = math.sin(phase * math.pi);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.15 + pulse * 0.45),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),

                const SizedBox(height: 12),

                AnimatedBuilder(
                  animation: _textCtrl,
                  builder: (context, _) => FadeTransition(
                    opacity: _textFade,
                    child: Text(
                      _showTimeout ? 'Iniciando servicios...' : 'Cargando',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.18),
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
