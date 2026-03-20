import 'dart:io';

void main() {
  final dir = Directory('lib');
  int count = 0;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    
    String content = entity.readAsStringSync();
    String original = content;

    // 1. Fix BoxDecoration wrapping
    // We replace instances where BoxDecoration immediately specifies color: context.ac.fg
    content = content.replaceAll(RegExp(r'BoxDecoration\(\s*color:\s*context\.ac\.fg\s*,', multiLine: true), 'BoxDecoration(color: context.ac.surface,');
    content = content.replaceAll(RegExp(r'BoxDecoration\(\s*color:\s*context\.ac\.fg\s*\)', multiLine: true), 'BoxDecoration(color: context.ac.surface)');

    // 2. Fix the generic hardcoded colors inside _AccionTile and others that missed the const filter
    content = content.replaceAll('color: Color(0xFF111827)', 'color: context.ac.fg');
    content = content.replaceAll('color: Color(0xFF6B7280)', 'color: context.ac.fgSubtle');
    
    // 3. Ensure the border lines are subtle
    content = content.replaceAll('border: Border.all(color: const Color(0xFFE5E7EB))', 'border: Border.all(color: context.ac.border)');
    content = content.replaceAll('border: Border.all(color: Color(0xFFE5E7EB))', 'border: Border.all(color: context.ac.border)');

    // 4. Any other container artifacts
    content = content.replaceAll('color: context.ac.fg,\n            borderRadius', 'color: context.ac.surface,\n            borderRadius');

    if (content != original) {
      entity.writeAsStringSync(content);
      count++;
    }
  }
  print('Fixed UI surface decorations in $count files.');
}
