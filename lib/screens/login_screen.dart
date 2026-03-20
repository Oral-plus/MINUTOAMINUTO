import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_sweetalert_new/art_sweetalert_new.dart';
import '../providers/app_provider.dart';
import '../models/supervisor.dart';
import '../models/vendedor.dart';
import '../services/data_service.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import 'home_screen.dart';
import 'setup_screen.dart';

enum _ConexionEstado { comprobando, conectado, error }

enum _CargoLogin { coach, kam, jefe, vendedor }

extension _CargoExt on _CargoLogin {
  String get label {
    switch (this) {
      case _CargoLogin.coach:    return 'Coach';
      case _CargoLogin.kam:      return 'KAM';
      case _CargoLogin.jefe:     return 'Jefe de Ventas';
      case _CargoLogin.vendedor: return 'Vendedor';
    }
  }

  String get sapKey {
    switch (this) {
      case _CargoLogin.coach: return 'COACH';
      case _CargoLogin.kam:   return 'KAM';
      default: return '';
    }
  }

  IconData get icon {
    switch (this) {
      case _CargoLogin.coach:    return Icons.sports_rounded;
      case _CargoLogin.kam:      return Icons.badge_rounded;
      case _CargoLogin.jefe:     return Icons.stars_rounded;
      case _CargoLogin.vendedor: return Icons.storefront_rounded;
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _nombreCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _formKey    = GlobalKey<FormState>();

  bool _showCodigo = false;
  bool _loading    = false;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;
  _ConexionEstado _conexion = _ConexionEstado.comprobando;

  // Cargo + SAP dropdown
  _CargoLogin      _cargo          = _CargoLogin.coach;
  String?          _selectedNombre;
  List<String>     _nombresSap     = [];
  bool             _loadingSap     = false;
  bool             _sapFallback    = false; // true cuando SAP no está disponible → campo libre

  late final Future<List<Supervisor>> _supervisoresFuture;
  late final Future<List<Vendedor>>   _vendedoresFuture;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _supervisoresFuture = DataService.getSupervisores()
        .timeout(const Duration(seconds: 20), onTimeout: () => <Supervisor>[])
        .catchError((_) => <Supervisor>[]);
    _vendedoresFuture = DataService.getVendedores()
        .timeout(const Duration(seconds: 20), onTimeout: () => <Vendedor>[])
        .catchError((_) => <Vendedor>[]);

    if (ApiConfig.useRemoteApi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verificarConexionApi();
        _cargarNombresSap();
      });
    } else {
      _conexion = _ConexionEstado.error;
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificarConexionApi() async {
    try {
      final ok = await ApiService.testConnection();
      if (mounted) setState(() => _conexion = ok ? _ConexionEstado.conectado : _ConexionEstado.error);
    } catch (_) {
      if (mounted) setState(() => _conexion = _ConexionEstado.error);
    }
  }

  Future<void> _cargarNombresSap() async {
    final sapKey = _cargo.sapKey;
    if (sapKey.isEmpty) {
      setState(() { _nombresSap = []; _sapFallback = false; _selectedNombre = null; });
      return;
    }
    setState(() { _loadingSap = true; _sapFallback = false; _selectedNombre = null; _nombresSap = []; });
    try {
      final nombres = await ApiService.getSupervisoresSap(sapKey);
      if (mounted) {
        if (nombres.isEmpty) {
          setState(() { _nombresSap = []; _sapFallback = true; _loadingSap = false; });
        } else {
          setState(() { _nombresSap = nombres; _loadingSap = false; });
        }
      }
    } catch (_) {
      if (mounted) setState(() { _sapFallback = true; _loadingSap = false; });
    }
  }

  Future<void> _login(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Nombre: dropdown SAP (si cargó) o campo libre
    final usaTexto = _cargo.sapKey.isEmpty || _sapFallback;
    final nombre = (usaTexto ? _nombreCtrl.text.trim() : (_selectedNombre ?? '')).toLowerCase();
    final codigo = _codigoCtrl.text.trim();

    if (nombre.isEmpty) {
      await ArtSweetAlert.show(
        context: context,
        title: const Text('Nombre requerido'),
        content: const Text('Por favor selecciona tu nombre de la lista.'),
        type: ArtAlertType.warning,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final supervisores = await _supervisoresFuture;
      final vendedores   = await _vendedoresFuture;

      Supervisor? sup;
      try {
        sup = supervisores.firstWhere(
          (s) => (s.nombre.toLowerCase().contains(nombre) || (s.alias != null && s.alias!.toLowerCase() == nombre)) && s.codigo == codigo,
        );
      } catch (_) {}

      Vendedor? ven;
      if (sup == null) {
        try {
          ven = vendedores.firstWhere(
            (v) => (v.nombre.toLowerCase().contains(nombre) || (v.alias != null && v.alias!.toLowerCase() == nombre)) && v.codigo == codigo,
          );
        } catch (_) {}
      }

      if (sup == null && ven == null) {
        if (mounted) {
          setState(() => _loading = false);
          await ArtSweetAlert.show(
            context: context,
            title: const Text('Credenciales incorrectas'),
            content: const Text('No se encontró ningún usuario con ese nombre y código.\nVerifique sus datos o contacte al administrador.'),
            type: ArtAlertType.error,
          );
        }
        return;
      }

      final provider = context.read<AppProvider>();
      if (sup != null) {
        await provider.loginSupervisor(sup.id);
      } else {
        await provider.loginVendedor(ven!.id);
      }
      
      // Lanzar el Wizard visual si el celular es Samsung AHORA, antes de navegar:
      if (mounted) {
        await provider.asegurarMonitorConWizardOpcional(context);
      }

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        await ArtSweetAlert.show(
          context: context,
          title: const Text('Error de conexión'),
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          type: ArtAlertType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            Positioned(
              top: -120, right: -100,
              child: Container(
                width: 350, height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Colors.white.withOpacity(0.035), Colors.transparent]),
                ),
              ),
            ),
            Positioned(
              bottom: -100, left: -80,
              child: Container(
                width: 280, height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Colors.white.withOpacity(0.025), Colors.transparent]),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Image.asset(
                        'assets/images/LOGO 2 1 (2).png',
                        height: MediaQuery.of(context).size.height * 0.12,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, _, _) => const Icon(Icons.schedule_rounded, size: 52, color: Colors.white),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'MINUTO A MINUTO',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'SEGUIMIENTO · PPVC · RVC',
                        style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.25), letterSpacing: 3),
                      ),
                      const SizedBox(height: 18),
                      _ApiStatusChip(estado: _conexion),
                      const SizedBox(height: 40),

                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131313),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white.withOpacity(0.09)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 50, offset: const Offset(0, 16)),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Header
                                Row(
                                  children: [
                                    Container(
                                      width: 42, height: 42,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                                      ),
                                      child: const Icon(Icons.lock_outline_rounded, color: Colors.white70, size: 20),
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Iniciar Sesión',
                                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                                        Text('Selecciona tu cargo y nombre',
                                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35))),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Selector de cargo
                                Text('TU CARGO',
                                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10,
                                        fontWeight: FontWeight.w700, letterSpacing: 2)),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8, runSpacing: 8,
                                  children: _CargoLogin.values.map((c) {
                                    final sel = _cargo == c;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() => _cargo = c);
                                        _cargarNombresSap();
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                                        decoration: BoxDecoration(
                                          color: sel ? Colors.white : Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                              color: sel ? Colors.white : Colors.white.withOpacity(0.12)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(c.icon, size: 13,
                                                color: sel ? Colors.black : Colors.white54),
                                            const SizedBox(width: 6),
                                            Text(c.label,
                                                style: TextStyle(
                                                    color: sel ? Colors.black : Colors.white70,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 20),

                                // Nombre
                                Text('TU NOMBRE',
                                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10,
                                        fontWeight: FontWeight.w700, letterSpacing: 2)),
                                const SizedBox(height: 10),

                                if (_cargo.sapKey.isNotEmpty && !_sapFallback) ...[
                                  if (_loadingSap)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
                                    )
                                  else if (_nombresSap.isNotEmpty)
                                    _SapDropdown(
                                      nombres: _nombresSap,
                                      selected: _selectedNombre,
                                      onChanged: (v) => setState(() => _selectedNombre = v),
                                    )
                                  else
                                    // SAP respondió pero sin datos → campo libre
                                    _DarkField(
                                      controller: _nombreCtrl,
                                      label: 'Nombre',
                                      hint: 'Ej: Juan Pérez',
                                      prefixIcon: Icons.person_outline_rounded,
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                                      textCapitalization: TextCapitalization.words,
                                    ),
                                ] else ...[
                                  // JEFE, VENDEDOR, o SAP no disponible → campo libre
                                  _DarkField(
                                    controller: _nombreCtrl,
                                    label: 'Nombre',
                                    hint: 'Ej: Juan Pérez',
                                    prefixIcon: Icons.person_outline_rounded,
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                                    textCapitalization: TextCapitalization.words,
                                  ),
                                  if (_sapFallback)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6, left: 4),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.refresh_rounded, size: 14, color: Colors.white30),
                                            onPressed: _cargarNombresSap,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                          ),
                                          const SizedBox(width: 4),
                                          Text('Cargar lista desde SAP',
                                              style: TextStyle(color: Colors.white30, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                ],
                                const SizedBox(height: 14),

                                // Campo código
                                _DarkField(
                                  controller: _codigoCtrl,
                                  label: 'Código',
                                  hint: 'Ej: S001',
                                  prefixIcon: Icons.pin_outlined,
                                  obscureText: !_showCodigo,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showCodigo ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: Colors.white30, size: 20,
                                    ),
                                    onPressed: () => setState(() => _showCodigo = !_showCodigo),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu código' : null,
                                ),
                                const SizedBox(height: 24),

                                _PremiumButton(
                                  label: _loading ? 'Verificando...' : 'Ingresar',
                                  enabled: !_loading,
                                  loading: _loading,
                                  onPressed: () => _login(context),
                                ),
                                const SizedBox(height: 14),
                                TextButton(
                                  onPressed: () => Navigator.pushReplacement(
                                    context, MaterialPageRoute(builder: (_) => const SetupScreen())),
                                  child: Text('Configurar equipo →',
                                      style: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SAP Dropdown ──────────────────────────────────────────────────────────────

class _SapDropdown extends StatelessWidget {
  final List<String> nombres;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _SapDropdown({required this.nombres, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (nombres.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text('No se encontraron nombres en SAP',
            style: TextStyle(color: Colors.white38, fontSize: 13)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(selected != null ? 0.35 : 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          hint: Text('Selecciona tu nombre',
              style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13)),
          dropdownColor: const Color(0xFF1A1A1A),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          icon: Icon(Icons.expand_more_rounded, color: Colors.white.withOpacity(0.4)),
          items: nombres.map((n) => DropdownMenuItem(
            value: n,
            child: Text(n, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Dark Text Field ────────────────────────────────────────────────────────────

class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;

  const _DarkField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.18), fontSize: 13),
        prefixIcon: Icon(prefixIcon, color: Colors.white30, size: 20),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.35)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF5350)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF5350)),
        ),
        filled: true,
        fillColor: const Color(0xFF0D0D0D),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        errorStyle: const TextStyle(color: Color(0xFFEF5350), fontSize: 11),
      ),
    );
  }
}

// ── API Status Chip ─────────────────────────────────────────────────────────

class _ApiStatusChip extends StatefulWidget {
  final _ConexionEstado estado;
  const _ApiStatusChip({required this.estado});
  @override
  State<_ApiStatusChip> createState() => _ApiStatusChipState();
}

class _ApiStatusChipState extends State<_ApiStatusChip> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isChecking = widget.estado == _ConexionEstado.comprobando;
    final isOk       = widget.estado == _ConexionEstado.conectado;
    final dotColor   = isChecking ? Colors.white38 : isOk ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
    final label      = isChecking ? 'Verificando conexión...' : isOk ? 'API conectada' : 'Sin conexión al servidor';
    final icon       = isChecking ? Icons.compare_arrows_rounded : isOk ? Icons.cloud_done_outlined : Icons.cloud_off_outlined;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isChecking ? Colors.white12 : isOk
                ? const Color(0xFF4CAF50).withOpacity(0.3)
                : const Color(0xFFE53935).withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isChecking)
              const SizedBox(width: 10, height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white38))
            else
              Opacity(
                opacity: 0.5 + _pulse.value * 0.5,
                child: Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              ),
            const SizedBox(width: 8),
            Icon(icon, size: 14,
                color: isChecking ? Colors.white38 : isOk ? const Color(0xFF66BB6A) : const Color(0xFFEF5350)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: isChecking ? Colors.white38 : isOk ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}

// ── Premium Button ──────────────────────────────────────────────────────────

class _PremiumButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;
  const _PremiumButton({required this.label, required this.enabled, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.white12,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [BoxShadow(color: Colors.white.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8))]
              : [],
        ),
        child: loading
            ? const Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54)))
            : Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: enabled ? Colors.black : Colors.white30,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.5)),
      ),
    );
  }
}
