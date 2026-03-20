import 'dart:io';

void main() {
  final dir = Directory('lib');
  int count = 0;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    
    String content = entity.readAsStringSync();
    String original = content;

    content = content.replaceAll('context.ac.fg30', 'context.ac.fgSubtle');
    content = content.replaceAll('context.ac.fg12', 'context.ac.border');
    content = content.replaceAll('context.ac.fg87', 'context.ac.fg');
    content = content.replaceAll('const CircularProgressIndicator', 'CircularProgressIndicator');
    content = content.replaceAll('const Widget', 'Widget');
    
    // Also remove generic const before Padding or Container that might have a dynamically colored child
    content = content.replaceAll('const Padding(', 'Padding(');
    content = content.replaceAll('const Center(', 'Center(');
    content = content.replaceAll('const SizedBox(', 'SizedBox(');

    if (content != original) {
      entity.writeAsStringSync(content);
      count++;
    }
  }
  print('Fixed residual artifacts in $count files.');
}
