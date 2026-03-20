import 'dart:io';

void main() {
  File mapFile = File('lib/widgets/map_location_modal.dart');
  if (mapFile.existsSync()) {
    var content = mapFile.readAsStringSync();
    content = content.replaceAll('color: context.ac.appBarBg,', 'color: ctx.ac.appBarBg,');
    mapFile.writeAsStringSync(content);
  }

  File diagFile = File('lib/services/call_diagnostic_service.dart');
  if (diagFile.existsSync()) {
    var content = diagFile.readAsStringSync();
    content = content.replaceAll('context.ac.fg38', 'context.ac.fg.withOpacity(0.38)');
    diagFile.writeAsStringSync(content);
  }

  File loginFile = File('lib/screens/login_screen.dart');
  if (loginFile.existsSync()) {
    var content = loginFile.readAsStringSync();
    content = content.replaceAll('const TextStyle(\n          color: enabled ? context.ac.fg : context.ac.border,', 'TextStyle(\n          color: enabled ? context.ac.fg : context.ac.border,');
    content = content.replaceAll('const TextStyle(\n                    color: enabled ? context.ac.fg : context.ac.fgSubtle,', 'TextStyle(\n                    color: enabled ? context.ac.fg : context.ac.fgSubtle,');
    content = content.replaceAll('color: enabled ? context.ac.fg : context.ac.border', 'color: enabled ? context.ac.fg : context.ac.border');
    
    // aggressive generic const strip around these
    content = content.replaceAll('const TextStyle(color: enabled', 'TextStyle(color: enabled');
    content = content.replaceAll('const TextStyle(\n        color: enabled', 'TextStyle(\n        color: enabled');
    content = content.replaceAll('const TextStyle(\n          color: enabled', 'TextStyle(\n          color: enabled');
    content = content.replaceAll('const TextStyle(\n                    color: enabled', 'TextStyle(\n                    color: enabled');
    loginFile.writeAsStringSync(content);
  }

  File misFile = File('lib/screens/mis_llamadas_screen.dart');
  if (misFile.existsSync()) {
    var content = misFile.readAsStringSync();
    content = content.replaceAll('context.ac.fg38', 'context.ac.fg.withOpacity(0.38)');
    content = content.replaceAll('context.ac.fg54', 'context.ac.fg.withOpacity(0.54)');
    content = content.replaceAll('return context.ac.fgSubtle;', 'return const Color(0xFF6B7280);'); // Fallback independent colors
    content = content.replaceAll('return context.ac.fg;', 'return const Color(0xFF111827);');
    content = content.replaceAll('return context.ac.fg.withOpacity(0.54);', 'return const Color(0xFF6B7280);');
    misFile.writeAsStringSync(content);
  }
}
