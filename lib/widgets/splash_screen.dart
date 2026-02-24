import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Pantalla de carga: diseño elegante, profesional y serio. Logo sin marco.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Opacity(
              opacity: _fadeAnimation.value,
              child: child,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 32),
                  _buildTitle(),
                  const SizedBox(height: 6),
                  _buildSubtitle(),
                  const SizedBox(height: 48),
                  _buildLoader(),
                  const SizedBox(height: 14),
                  _buildLoadingLabel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo.png',
      height: 180,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(
        Icons.schedule_rounded,
        size: 72,
        color: AppConstants.azulCorporativo.withOpacity(0.7),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Minuto a Minuto',
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF0F172A),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Seguimiento PPVC y RVC',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: const Color(0xFF64748B),
      ),
    );
  }

  Widget _buildLoader() {
    return SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(AppConstants.azulCorporativo),
        backgroundColor: const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildLoadingLabel() {
    return Text(
      'Cargando…',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: const Color(0xFF94A3B8),
      ),
    );
  }
}
