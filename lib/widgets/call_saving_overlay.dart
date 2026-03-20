import 'dart:async';
import 'package:flutter/material.dart';
import '../services/call_saving_progress_service.dart';

/// Overlay premium que aparece en la parte inferior mientras se guarda la grabación.
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
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);

    _sub = CallSavingProgressService.stream.listen((p) {
      if (!mounted) return;
      setState(() => _progress = p);
      if (p.isActive) {
        _animCtrl.forward();
      } else if (p.isDone) {
        Future.delayed(const Duration(milliseconds: 2800), () {
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
      children: [
        widget.child,
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1.5),
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

    final Color accent = isError
        ? const Color(0xFFE53935)
        : isDone
            ? const Color(0xFF43A047)
            : Colors.white;

    final IconData icon = isError
        ? Icons.error_outline_rounded
        : isDone
            ? Icons.check_circle_outline_rounded
            : Icons.cloud_upload_outlined;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.07),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    progress.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),
                if (!isDone && !isError)
                  Text(
                    '${(progress.percent * 100).toInt()}%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            if (!isDone && !isError) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.percent,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
