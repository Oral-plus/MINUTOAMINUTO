import '../utils/app_theme.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Loader corporativo reutilizable: fondo blanco, logo y 3 bolitas animadas.
class AppLoadingScreen extends StatelessWidget {
  final bool showMessage;
  final String message;

  const AppLoadingScreen({
    super.key,
    this.showMessage = false,
    this.message = 'Cargando...',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: SafeArea(
        child: Center(
          child: AppLoadingIndicator(
            showMessage: showMessage,
            message: message,
          ),
        ),
      ),
    );
  }
}

class AppLoadingIndicator extends StatelessWidget {
  final double logoHeight;
  final double dotSize;
  final double dotSpacing;
  final bool showMessage;
  final String message;

  const AppLoadingIndicator({
    super.key,
    this.logoHeight = 138,
    this.dotSize = 10,
    this.dotSpacing = 8,
    this.showMessage = false,
    this.message = 'Cargando...',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ambient glow behind logo
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: logoHeight * 1.5,
              height: logoHeight * 1.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.ac.fg.withOpacity(0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Image.asset(
              'assets/images/LOGO 2 1 (2).png',
              height: logoHeight,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (ctx, err, st) => Image.asset(
                'assets/images/LLAMADA.png',
                height: logoHeight,
                fit: BoxFit.contain,
                errorBuilder: (ctx2, err2, st2) => Icon(
                  Icons.schedule_rounded,
                  size: logoHeight * 0.45,
                  color: context.ac.fg,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 24),
        _AnimatedLoadingDots(
          dotSize: dotSize,
          spacing: dotSpacing,
          color: context.ac.fg,
        ),
        if (showMessage) ...[
          SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.ac.fg.withOpacity(0.3),
            ),
          ),
        ],
      ],
    );
  }
}

class _AnimatedLoadingDots extends StatefulWidget {
  final double dotSize;
  final double spacing;
  final Color color;

  const _AnimatedLoadingDots({
    required this.dotSize,
    required this.spacing,
    required this.color,
  });

  @override
  State<_AnimatedLoadingDots> createState() => _AnimatedLoadingDotsState();
}

class _AnimatedLoadingDotsState extends State<_AnimatedLoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _factorFor(int index, double t) {
    final shifted = (t + 1 - (index * 0.16)) % 1;
    final wave = (math.sin(shifted * math.pi * 2) + 1) / 2;
    return Curves.easeInOut.transform(wave);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final factor = _factorFor(index, t);
            final opacity = 0.35 + (0.65 * factor);
            final offsetY = -3.5 * factor;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
              child: Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, offsetY),
                  child: Container(
                    width: widget.dotSize,
                    height: widget.dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
