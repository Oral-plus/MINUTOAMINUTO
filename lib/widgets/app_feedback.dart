import 'package:flutter/material.dart';
import '../utils/constants.dart';

enum FeedbackType { success, error, warning, info }

class AppFeedback {
  static void show(
    BuildContext context, {
    required String message,
    FeedbackType type = FeedbackType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    final (Color bg, Color fg, IconData icon) = switch (type) {
      FeedbackType.success => (
          const Color(0xFF059669),
          Colors.white,
          Icons.check_circle_rounded,
        ),
      FeedbackType.error => (
          const Color(0xFFDC2626),
          Colors.white,
          Icons.error_rounded,
        ),
      FeedbackType.warning => (
          const Color(0xFFF59E0B),
          const Color(0xFF1C1917),
          Icons.warning_amber_rounded,
        ),
      FeedbackType.info => (
          const Color(0xFF2563EB),
          Colors.white,
          Icons.info_rounded,
        ),
    };

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: fg,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  static void success(BuildContext context, String message) =>
      show(context, message: message, type: FeedbackType.success);

  static void error(BuildContext context, String message) =>
      show(context, message: message, type: FeedbackType.error, duration: const Duration(seconds: 5));

  static void warning(BuildContext context, String message) =>
      show(context, message: message, type: FeedbackType.warning);

  static void info(BuildContext context, String message) =>
      show(context, message: message, type: FeedbackType.info);

  static Future<bool> confirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    Color? confirmColor,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: (confirmColor ?? AppConstants.azulCorporativo)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: confirmColor ?? AppConstants.azulCorporativo,
                    size: 26,
                  ),
                ),
              if (icon != null) const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF6B7280),
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      child: Text(
                        cancelLabel,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            confirmColor ?? AppConstants.azulCorporativo,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: const Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class AppInlineLoader extends StatelessWidget {
  final String? label;

  const AppInlineLoader({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppConstants.azulCorporativo,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 10),
            Text(
              label!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
