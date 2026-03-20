import '../utils/app_theme.dart';
import 'package:flutter/material.dart';
import '../services/call_monitor_service.dart';
import 'dart:math';

class ActiveCallIndicator extends StatelessWidget {
  const ActiveCallIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CallMonitorService.isInCallNotifier,
      builder: (context, isInCall, child) {
        if (!isInCall) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: context.ac.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.3),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const _RecordingPulseIcon(),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grabación en curso...',
                      style: TextStyle(
                        color: context.ac.fg,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Capturando audio de la llamada (Micófono y Altavoz)',
                      style: TextStyle(
                        color: context.ac.fg.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              const _AudioWaveform(),
            ],
          ),
        );
      },
    );
  }
}

class _RecordingPulseIcon extends StatefulWidget {
  const _RecordingPulseIcon();

  @override
  State<_RecordingPulseIcon> createState() => _RecordingPulseIconState();
}

class _RecordingPulseIconState extends State<_RecordingPulseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withValues(alpha: 0.5 + (_controller.value * 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: _controller.value * 0.8),
                blurRadius: 8,
                spreadRadius: 2,
              )
            ],
          ),
        );
      },
    );
  }
}

class _AudioWaveform extends StatelessWidget {
  const _AudioWaveform();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: CallMonitorService.callAmplitudeNotifier,
      builder: (context, amplitude, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            // Un poco de ruido visual aleatorio basado en la amplitud
            final randomModifier = (Random().nextDouble() * 0.5 + 0.5);
            // Hacer que las barras del medio sean más altas
            final positionalModifier = 1.0 - (2 - index).abs() * 0.2;
            
            // Altura mínima de 4, máxima de 24
            final barHeight = 4.0 + (20.0 * amplitude * randomModifier * positionalModifier);
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: barHeight,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
