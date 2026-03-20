import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class SamsungSetupWizard {
  static const String _keySamsungSetupDone = 'samsung_setup_wizard_done';

  /// Muestra el asistente visual si es un dispositivo Samsung y no se ha mostrado antes.
  /// Retorna `true` si el asistente se mostró (para esperar que el usuario lo cierre)
  /// o `false` si no era necesario.
  static Future<bool> checkAndShow(BuildContext context) async {
    if (!Platform.isAndroid) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_keySamsungSetupDone) == true) return false;

      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final manufacturer = androidInfo.manufacturer.toLowerCase();

      if (manufacturer.contains('samsung')) {
        if (!context.mounted) return false;
        await _showDialog(context);
        await prefs.setBool(_keySamsungSetupDone, true);
        return true;
      }
    } catch (e) {
      debugPrint('SamsungSetupWizard error: $e');
    }
    return false;
  }

  static Future<void> _showDialog(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _SamsungWizardDialog(),
    );
  }
}

class _SamsungWizardDialog extends StatefulWidget {
  const _SamsungWizardDialog();

  @override
  State<_SamsungWizardDialog> createState() => _SamsungWizardDialogState();
}

class _SamsungWizardDialogState extends State<_SamsungWizardDialog> {
  int _step = 0;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Activación Requerida',
      'desc': 'Hemos detectado que usas un dispositivo Samsung. Para que "Minuto a Minuto" pueda analizar tus llamadas con calidad perfecta, debes activar una función nativa de tu teléfono.',
      'icon': Icons.warning_rounded,
      'color': Colors.amber,
    },
    {
      'title': 'Paso 1: Ve a tu Teléfono',
      'desc': 'Abre la aplicación oficial de llamadas de Samsung (el icono verde donde marcas los números de teléfono).',
      'icon': Icons.call_rounded,
      'color': Colors.green,
    },
    {
      'title': 'Paso 2: Entra a Ajustes',
      'desc': 'Toca los 3 puntitos en la esquina superior derecha y selecciona "Ajustes". Luego busca la opción "Grabar llamadas".',
      'icon': Icons.settings_rounded,
      'color': Colors.blue,
    },
    {
      'title': 'Paso 3: Activar Automatización',
      'desc': 'Enciende el interruptor "Grabar llamadas automáticamente".\n\n¡Listo! Vuelve a Minuto a Minuto. La app ahora se encargará de todo mágicamente.',
      'icon': Icons.auto_mode_rounded,
      'color': Colors.purpleAccent,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final cur = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: cur['color'].withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: cur['color'].withOpacity(0.15),
              blurRadius: 40,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cur['color'].withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                cur['icon'],
                size: 48,
                color: cur['color'],
              ),
            ),
            const SizedBox(height: 24),

            // Text
            Text(
              cur['title'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              cur['desc'],
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (i) {
                final active = i == _step;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? cur['color'] : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // Buttons
            Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Atrás', style: TextStyle(color: Colors.white54)),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      if (isLast) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() => _step++);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: cur['color'],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isLast ? '¡Entendido, a configurar!' : 'Siguiente',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
