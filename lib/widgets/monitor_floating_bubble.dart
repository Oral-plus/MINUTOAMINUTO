import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Burbuja flotante: normal = monitor activo, recording = grabando audio.
class MonitorFloatingBubble extends StatefulWidget {
  const MonitorFloatingBubble({super.key});

  @override
  State<MonitorFloatingBubble> createState() => _MonitorFloatingBubbleState();
}

class _MonitorFloatingBubbleState extends State<MonitorFloatingBubble> {
  StreamSubscription<Object?>? _sub;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _sub = FlutterOverlayWindow.overlayListener.listen((event) {
      final s = event.toString().trim().toLowerCase();
      if (mounted) setState(() {
        _isRecording = s == 'recording';
      });
    });
  }

  @override
  void dispose() {
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: _isRecording
                  ? const Color(0xDDC62828)
                  : const Color(0xDD1565C0),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Icon(
              _isRecording ? Icons.mic_rounded : Icons.phone_in_talk_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
