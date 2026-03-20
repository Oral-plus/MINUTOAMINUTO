import '../utils/app_theme.dart';
import 'package:flutter/material.dart';

/// Banner premium que aparece en la parte superior cuando se graba una llamada.
class RecordingOverlay extends StatefulWidget {
  final bool visible;
  const RecordingOverlay({super.key, this.visible = true});

  @override
  State<RecordingOverlay> createState() => _RecordingOverlayState();
}

class _RecordingOverlayState extends State<RecordingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;
  late Animation<double> _dotAnim;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _dotAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _dotController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: context.ac.fg.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _dotAnim,
                builder: (_, _) => Opacity(
                  opacity: _dotAnim.value,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Text(
                'GRABANDO',
                style: TextStyle(
                  color: context.ac.fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 2.5,
                ),
              ),
              SizedBox(width: 10),
              Icon(Icons.mic_rounded, color: Color(0xFFE53935), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
