import 'dart:io';

void main() {
  final file = File('lib/screens/home_screen.dart');
  var content = file.readAsStringSync();
  
  // Replace the phone number dialog logic
  final oldLogic = RegExp(r'if\s*\(num\.isEmpty\)\s*\{[\s\S]+?\}');
  content = content.replaceFirst(oldLogic, 'await provider.actualizarTelefonoActual(num);');
  
  // Also remove the unused 'prefs' variable in that function
  content = content.replaceFirst('final prefs = await SharedPreferences.getInstance();', '// prefs refactorizada');
  
  file.writeAsStringSync(content);
  print('HomeScreen.dart updated');
}
