import 'dart:io';

void main() {
  File loginFile = File('lib/screens/login_screen.dart');
  if (loginFile.existsSync()) {
    var content = loginFile.readAsStringSync();
    content = content.replaceAll('context.ac.fg38', 'context.ac.fgSubtle');
    content = content.replaceAll('context.ac.fg12', 'context.ac.border');
    content = content.replaceAll('context.ac.fg30', 'context.ac.fgSubtle');
    loginFile.writeAsStringSync(content);
  }

  File mapFile = File('lib/widgets/map_location_modal.dart');
  if (mapFile.existsSync()) {
    var content = mapFile.readAsStringSync();
    content = content.replaceAll('color: context.ac.appBarBg,', 'color: ctx.ac.appBarBg,');
    mapFile.writeAsStringSync(content);
  }
}
