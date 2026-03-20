import 'dart:io';

void main() {
  File callFile = File('lib/widgets/call_saving_overlay.dart');
  if (callFile.existsSync()) {
    var content = callFile.readAsStringSync();
    content = content.replaceAll('const AlwaysStoppedAnimation<Color>(context.ac.fg)', 'AlwaysStoppedAnimation<Color>(context.ac.fg)');
    callFile.writeAsStringSync(content);
  }

  File debugFile = File('lib/services/debug_alert_service.dart');
  if (debugFile.existsSync()) {
    var content = debugFile.readAsStringSync();
    content = content.replaceAll('context.ac.fgSubtle', 'const Color(0x99FFFFFF)');
    content = content.replaceAll('context.ac.fg', 'const Color(0xFFFFFFFF)');
    debugFile.writeAsStringSync(content);
  }

  File samsungFile = File('lib/widgets/samsung_setup_wizard.dart');
  if (samsungFile.existsSync()) {
    var content = samsungFile.readAsStringSync();
    content = content.replaceAll('context.ac.fg24', 'context.ac.fg.withOpacity(0.24)');
    samsungFile.writeAsStringSync(content);
  }

  File mapFile = File('lib/widgets/map_location_modal.dart');
  if (mapFile.existsSync()) {
    var content = mapFile.readAsStringSync();
    content = content.replaceAll('color: ctx.ac.appBarBg', 'color: context.ac.appBarBg');
    mapFile.writeAsStringSync(content);
  }
}
