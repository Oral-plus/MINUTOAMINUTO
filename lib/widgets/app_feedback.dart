import '../utils/app_theme.dart';
import 'package:flutter/material.dart';

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
      FeedbackType.success => (context.ac.surface, context.ac.fg, Icons.check_circle_rounded),
      FeedbackType.error => (context.ac.surface, context.ac.fg, Icons.error_rounded),
      FeedbackType.warning => (context.ac.surfaceAlt, context.ac.fg, Icons.warning_amber_rounded),
      FeedbackType.info => (context.ac.surface, context.ac.fg, Icons.info_rounded),
    };

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: fg, size: 20),
            SizedBox(width: 10),
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
                    color: (confirmColor ?? context.ac.surfaceAlt)
                        .withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: confirmColor ?? context.ac.fg,
                    size: 26,
                  ),
                ),
              if (icon != null) SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.ac.fg,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 13.5,
                  color: context.ac.fgSubtle,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
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
                        side: BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      child: Text(
                        cancelLabel,
                        style: TextStyle(
                          color: context.ac.fg.withOpacity(0.54),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            confirmColor ?? context.ac.fg,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: TextStyle(fontWeight: FontWeight.w600),
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
                color: context.ac.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: context.ac.fgSubtle),
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.ac.fg,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: 6),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  color: context.ac.fg.withOpacity(0.54),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: 16),
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
              color: context.ac.fg,
            ),
          ),
          if (label != null) ...[
            SizedBox(height: 10),
            Text(
              label!,
              style: TextStyle(
                fontSize: 12,
                color: context.ac.fgSubtle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
