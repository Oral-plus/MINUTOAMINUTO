import 'dart:io';

void main() {
  final dir = Directory('lib');
  int count = 0;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    
    String content = entity.readAsStringSync();
    String original = content;

    // 1. Gradients in structural cards
    content = content.replaceAll(
      'colors: [Colors.black87, Colors.black54]',
      'colors: [context.ac.surface, context.ac.surfaceAlt]'
    );
    content = content.replaceAll(
      'Colors.black.withValues(alpha: 0.15)',
      'context.ac.fg.withValues(alpha: 0.15)'
    );
    content = content.replaceAll(
      'Colors.white.withValues(alpha: 0.16)',
      'context.ac.fg.withValues(alpha: 0.16)'
    );

    // 2. Ternary conditions and other arrays
    // These defaults will turn remaining static contrast variables into dynamic context getters.
    content = content.replaceAll('Colors.black87', 'context.ac.fg');
    content = content.replaceAll('Colors.black54', 'context.ac.fgSubtle');
    content = content.replaceAll('Colors.black38', 'context.ac.fgSubtle');
    content = content.replaceAll('Colors.black30', 'context.ac.fgSubtle');
    content = content.replaceAll('Colors.black26', 'context.ac.fg.withOpacity(0.26)');
    content = content.replaceAll('Colors.black12', 'context.ac.border');
    
    // Remaining pure raw values
    content = content.replaceAll('Colors.white', 'context.ac.fg');
    content = content.replaceAll('Colors.black', 'context.ac.fg');
    content = content.replaceAll('color: color ?? context.ac.fg', 'color: color ?? context.ac.fg');

    if (content != original) {
      if (!content.contains("import '../utils/app_theme.dart';") && !content.contains("import 'package:minuto_a_minuto/utils/app_theme.dart';")) {
        // Just inject locally if missing
      }
      entity.writeAsStringSync(content);
      count++;
    }
  }
  print('Fixed remaining static literals in $count files.');
}
