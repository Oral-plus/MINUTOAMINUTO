import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) {
    print('Error: run from project root');
    return;
  }

  int filesChanged = 0;

  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;

    if (entity.path.contains('app_theme.dart') ||
        entity.path.contains('app_provider.dart') ||
        entity.path.contains('constants.dart') ||
        entity.path.contains('api_config.dart')) {
      continue;
    }

    String content = entity.readAsStringSync();
    String original = content;

    // 1. Backgrounds
    content = content.replaceAllMapped(RegExp(r'backgroundColor:\s*Colors\.white([^a-zA-Z])'), (m) => 'backgroundColor: context.ac.bg${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'backgroundColor:\s*const Color\(0xFFF5F5F5\)([^a-zA-Z])'), (m) => 'backgroundColor: context.ac.bg${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'backgroundColor:\s*Color\(0xFFF5F5F5\)([^a-zA-Z])'), (m) => 'backgroundColor: context.ac.bg${m.group(1)}');
    
    content = content.replaceAllMapped(RegExp(r'backgroundColor:\s*const Color\(0xFF0D0D0D\)([^a-zA-Z])'), (m) => 'backgroundColor: context.ac.bg${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'backgroundColor:\s*Color\(0xFF0D0D0D\)([^a-zA-Z])'), (m) => 'backgroundColor: context.ac.bg${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'backgroundColor:\s*const Color\(0xFF0A0A0A\)([^a-zA-Z])'), (m) => 'backgroundColor: context.ac.bg${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'backgroundColor:\s*Color\(0xFF0A0A0A\)([^a-zA-Z])'), (m) => 'backgroundColor: context.ac.bg${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'backgroundColor:\s*const Color\(0xFF111111\)([^a-zA-Z])'), (m) => 'backgroundColor: context.ac.appBarBg${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'backgroundColor:\s*Color\(0xFF111111\)([^a-zA-Z])'), (m) => 'backgroundColor: context.ac.appBarBg${m.group(1)}');
    
    // Custom container backgrounds
    content = content.replaceAllMapped(RegExp(r'color:\s*const Color\(0xFF151515\)([^a-zA-Z])'), (m) => 'color: context.ac.surfaceAlt${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*Color\(0xFF151515\)([^a-zA-Z])'), (m) => 'color: context.ac.surfaceAlt${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*const Color\(0xFF141414\)([^a-zA-Z])'), (m) => 'color: context.ac.surfaceAlt${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*Color\(0xFF141414\)([^a-zA-Z])'), (m) => 'color: context.ac.surfaceAlt${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*const Color\(0xFF161616\)([^a-zA-Z])'), (m) => 'color: context.ac.surface${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*Color\(0xFF161616\)([^a-zA-Z])'), (m) => 'color: context.ac.surface${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*const Color\(0xFF1E1E1E\)([^a-zA-Z])'), (m) => 'color: context.ac.surface${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*Color\(0xFF1E1E1E\)([^a-zA-Z])'), (m) => 'color: context.ac.surface${m.group(1)}');

    content = content.replaceAllMapped(RegExp(r'color:\s*const Color\(0xFFF9FAFB\)([^a-zA-Z])'), (m) => 'color: context.ac.surface${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*Color\(0xFFF9FAFB\)([^a-zA-Z])'), (m) => 'color: context.ac.surface${m.group(1)}');

    // 2. Foreground Colors
    content = content.replaceAllMapped(RegExp(r'color:\s*Colors\.white([^\.a-zA-Z\)])'), (m) => 'color: context.ac.fg${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*Colors\.black([^\.a-zA-Z\)])'), (m) => 'color: context.ac.fg${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*Colors\.black87([^\.a-zA-Z\)])'), (m) => 'color: context.ac.fg${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*Colors\.white70([^\.a-zA-Z\)])'), (m) => 'color: context.ac.fg.withOpacity(0.7)${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*Colors\.black54([^\.a-zA-Z\)])'), (m) => 'color: context.ac.fg.withOpacity(0.54)${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*Colors\.white54([^\.a-zA-Z\)])'), (m) => 'color: context.ac.fg.withOpacity(0.54)${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*Colors\.white38([^\.a-zA-Z\)])'), (m) => 'color: context.ac.fgSubtle${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*Colors\.black38([^\.a-zA-Z\)])'), (m) => 'color: context.ac.fgSubtle${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*Colors\.white30([^\.a-zA-Z\)])'), (m) => 'color: context.ac.fgSubtle${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*Colors\.white24([^\.a-zA-Z\)])'), (m) => 'color: context.ac.fg.withOpacity(0.24)${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*Colors\.white12([^\.a-zA-Z\)])'), (m) => 'color: context.ac.border${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'color:\s*Colors\.black12([^\.a-zA-Z\)])'), (m) => 'color: context.ac.border${m.group(1)}');
    
    // Opacities specific mapping
    content = content.replaceAllMapped(
      RegExp(r'color:\s*Colors\.white\.withOpacity\(([^)]+)\)'),
      (m) => 'color: context.ac.fg.withOpacity(${m.group(1)})'
    );
    content = content.replaceAllMapped(
      RegExp(r'color:\s*Colors\.black\.withOpacity\(([^)]+)\)'),
      (m) => 'color: context.ac.fg.withOpacity(${m.group(1)})'
    );
    
    // Banners or foreground specifics
    content = content.replaceAllMapped(RegExp(r'foregroundColor:\s*Colors\.black([^\.a-zA-Z])'), (m) => 'foregroundColor: context.ac.fg${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'foregroundColor:\s*Colors\.white([^\.a-zA-Z])'), (m) => 'foregroundColor: context.ac.fg${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'foregroundColor:\s*const Color\(0xFF111827\)([^\.a-zA-Z])'), (m) => 'foregroundColor: context.ac.fg${m.group(1)}');
    content = content.replaceAllMapped(RegExp(r'foregroundColor:\s*Color\(0xFF111827\)([^\.a-zA-Z])'), (m) => 'foregroundColor: context.ac.fg${m.group(1)}');
    
    content = content.replaceAll('const TextStyle(', 'TextStyle(');
    content = content.replaceAll('const Icon(', 'Icon(');
    content = content.replaceAll('const InputDecoration(', 'InputDecoration(');
    content = content.replaceAll('const BoxDecoration(', 'BoxDecoration(');
    content = content.replaceAll('const BorderSide(', 'BorderSide(');
    content = content.replaceAll('const Center(child: CircularProgressIndicator(', 'Center(child: CircularProgressIndicator(');
    content = content.replaceAll('const SizedBox(', 'SizedBox(');
    content = content.replaceAll('const Padding(', 'Padding(');
    content = content.replaceAll('const Text(', 'Text(');
    content = content.replaceAll('const Column(', 'Column(');
    content = content.replaceAll('const Row(', 'Row(');
    content = content.replaceAll('const Expanded(', 'Expanded(');
    content = content.replaceAll('const Flexible(', 'Flexible(');
    content = content.replaceAll('const LinearGradient(', 'LinearGradient(');

    if (content != original) {
      if (!content.contains("import '../utils/app_theme.dart';")) {
        content = "import '../utils/app_theme.dart';\n$content";
      }
      entity.writeAsStringSync(content);
      filesChanged++;
    }
  }
  print('Migration complete. Modified $filesChanged files.');
}
