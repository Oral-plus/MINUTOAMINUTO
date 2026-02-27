import 'dart:async';
import 'package:flutter/material.dart';
import '../services/call_saving_progress_service.dart';

/// Overlay que aparece en la parte inferior de la pantalla mientras se guarda
/// la grabación post-llamada. Se muestra automáticamente y desaparece solo.
class CallSavingOverlay extends StatefulWidget {
  final Widget child;
  const CallSavingOverlay({super.key, required this.child});

  @override
  State<CallSavingOverlay> createState() => _CallSavingOverlayState();
}

class _CallSavingOverlayState extends State<CallSavingOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription<CallSavingProgress>? _sub;
  CallSavingProgress _progress = CallSavingProgressService.current;
  late AnimationController _animCtrl;
  late Animation<double> _slideAnim;

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

    // Si ya hay progreso activo al montar (ej: segundo plano)
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

class SavingBanner extends StatelessWidget {
  final CallSavingProgress progress;
  const SavingBanner({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final isDone = progress.stage == SavingStage.listo;
    final isError = progress.stage == SavingStage.error;

    final Color bgColor = isError
        ? const Color(0xFFC62828)
        : isDone
            ? const Color(0xFF2E7D32)
            : const Color(0xFF1565C0);

    final IconData icon = isError
        ? Icons.error_outline
        : isDone
            ? Icons.check_circle_outline
            : Icons.cloud_upload_outlined;

    return Material(
      elevation: 8,
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    progress.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (!isDone && !isError)
                  Text(
                    '${(progress.percent * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            if (!isDone && !isError) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.percent,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
