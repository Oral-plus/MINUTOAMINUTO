import 'dart:io';

void main() {
  final file = File('lib/screens/home_screen.dart');
  var content = file.readAsStringSync();
  
  // 1. Fix the top part of the function
  content = content.replaceFirst(
    RegExp(r'Future<void> _mostrarDialogoMiNumero\(BuildContext context, AppProvider provider\) async \{[\s\S]+?final ctrl = TextEditingController\(text: actual\);'),
    'Future<void> _mostrarDialogoMiNumero(BuildContext context, AppProvider provider) async {\n    final actual = provider.usuarioActual?.telefono ??\n        provider.vendedorActual?.telefono ??\n        \'\';\n    final ctrl = TextEditingController(text: actual);'
  );
  
  // 2. Fix the save button part
  content = content.replaceFirst(
    RegExp(r'onPressed: \(\) async \{[\s\S]+?await provider\.actualizarTelefonoActual\(num\);[\s\S]+?if \(ctx\.mounted\) Navigator\.pop\(ctx\);'),
    'onPressed: () async {\n              final num = ctrl.text.trim();\n              await provider.actualizarTelefonoActual(num);\n              if (ctx.mounted) Navigator.pop(ctx);\n            }'
  );
  
  file.writeAsStringSync(content);
  print('HomeScreen.dart fixed');
}
