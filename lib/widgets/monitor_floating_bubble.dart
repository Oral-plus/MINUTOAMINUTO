import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Burbuja flotante premium: muestra el estado de monitoreo y grabación.
class MonitorFloatingBubble extends StatefulWidget {
  const MonitorFloatingBubble({super.key});

  @override
  State<MonitorFloatingBubble> createState() => _MonitorFloatingBubbleState();
}

class _MonitorFloatingBubbleState extends State<MonitorFloatingBubble>
    with TickerProviderStateMixin {
  StreamSubscription<Object?>? _sub;
  bool _isRecording = false;

  late AnimationController _pulseController;
  late AnimationController _ringController;
  late Animation<double> _pulseAnim;
  late Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ringAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );

    _sub = FlutterOverlayWindow.overlayListener.listen((event) {
      final s = event.toString().trim().toLowerCase();
      if (mounted) {
        setState(() => _isRecording = s == 'recording');
        if (_isRecording) {
          _pulseController.repeat(reverse: true);
          _ringController.repeat();
        } else {
          _pulseController.stop();
          _pulseController.animateTo(0.5);
          _ringController.stop();
          _ringController.reset();
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: GestureDetector(
          onTap: () => FlutterOverlayWindow.shareData('open_calls'),
          onLongPress: () => FlutterOverlayWindow.shareData('open_home'),
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulseAnim, _ringAnim]),
            builder: (context, child) {
              return SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Expanding ring when recording
                    if (_isRecording)
                      Opacity(
                        opacity: (1.0 - _ringAnim.value).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 1.0 + _ringAnim.value * 0.8,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFD32F2F),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Main bubble
                    Transform.scale(
                      scale: _isRecording ? _pulseAnim.value : 1.0,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isRecording
                                ? [const Color(0xFFB71C1C), const Color(0xFFE53935)]
                                : [const Color(0xFF1A1A1A), const Color(0xFF3A3A3A)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _isRecording
                                  ? const Color(0xFFE53935).withValues(alpha: 0.5)
                                  : Colors.black.withValues(alpha: 0.4),
                              blurRadius: _isRecording ? 18 : 12,
                              spreadRadius: _isRecording ? 2 : 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.mic_rounded : Icons.shield_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    // Recording dot indicator
                    if (_isRecording)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF1744),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
