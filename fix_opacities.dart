import 'dart:io';

void main() {
  final dir = Directory('lib');
  int count = 0;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    
    String content = entity.readAsStringSync();
    String original = content;

    content = content.replaceAll('context.ac.fg54', 'context.ac.fg.withOpacity(0.54)');
    content = content.replaceAll('context.ac.fg70', 'context.ac.fg.withOpacity(0.7)');
    content = content.replaceAll('context.ac.fg38', 'context.ac.fgSubtle');
    
    if (content != original) {
      entity.writeAsStringSync(content);
      count++;
    }
  }
  print('Fixed opacities in $count files.');
}
