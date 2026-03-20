import 'dart:io';

void main() {
  final dir = Directory('lib');
  int count = 0;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    
    String content = entity.readAsStringSync();
    String original = content;

    content = content.replaceAll('FeedbackType.success => (context.ac.fg, context.ac.fg', 'FeedbackType.success => (context.ac.surface, context.ac.fg');
    content = content.replaceAll('FeedbackType.error => (context.ac.fg, context.ac.fg', 'FeedbackType.error => (context.ac.surface, context.ac.fg');
    content = content.replaceAll('FeedbackType.warning => (context.ac.fgSubtle, context.ac.fg', 'FeedbackType.warning => (context.ac.surfaceAlt, context.ac.fg');
    content = content.replaceAll('FeedbackType.info => (context.ac.fg, context.ac.fg', 'FeedbackType.info => (context.ac.surface, context.ac.fg');
    
    content = content.replaceAll('const Color(0xFFF5F5F5)', 'context.ac.surfaceAlt');
    content = content.replaceAll('const Color(0xFF1A2A3A)', 'context.ac.appBarBg');

    // Also the login screen generic container that had Colors.black
    content = content.replaceAll('color: (confirmColor ?? context.ac.fg)', 'color: (confirmColor ?? context.ac.surfaceAlt)');
    
    if (content != original) {
      entity.writeAsStringSync(content);
      count++;
    }
  }
  print('Fixed tuple backgrounds in $count files.');
}
