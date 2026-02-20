import 'package:flutter/material.dart';

/// Pantalla de carga con logo, círculos animados, texto "Minuto a Minuto" y efecto de cargando.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _circleController;

  @override
  void initState() {
    super.initState();
    _circleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _circleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Círculos animados de carga detrás del logo
              Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _circleController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(180, 180),
                        painter: _PulsingCirclesPainter(
                          progress: _circleController.value,
                        ),
                      );
                    },
                  ),
                  // Logo principal
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 90,
                      width: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.image,
                        size: 70,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // Texto "Minuto a Minuto"
              Text(
                'MINUTO A MINUTO',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Seguimiento PPVC y RVC',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              // Círculo de carga + texto Cargando
              Column(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: Colors.blue.shade700,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando...',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingCirclesPainter extends CustomPainter {
  final double progress;

  _PulsingCirclesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final colors = [
      Colors.blue.shade100.withValues(alpha: 0.5),
      Colors.blue.shade200.withValues(alpha: 0.4),
      Colors.blue.shade300.withValues(alpha: 0.3),
    ];
    for (var i = 0; i < 3; i++) {
      final t = (progress + i * 0.33) % 1.0;
      final scale = 0.5 + (t * 0.8);
      final radius = 40.0 + (scale * 35);
      final alpha = (1 - t) * 0.4;
      final paint = Paint()
        ..color = colors[i].withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulsingCirclesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
