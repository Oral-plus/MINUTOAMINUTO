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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _nombreCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showCodigo = false;
  bool _loading = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  _ConexionEstado _conexion = _ConexionEstado.comprobando;

  late final Future<List<Supervisor>> _supervisoresFuture;
  late final Future<List<Vendedor>> _vendedoresFuture;

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _verificarConexionApi());
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

  Future<void> _login(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);

    final nombre = _nombreCtrl.text.trim().toLowerCase();
    final codigo = _codigoCtrl.text.trim();

    try {
      final supervisores = await _supervisoresFuture;
      final vendedores = await _vendedoresFuture;

      // Buscar en supervisores
      Supervisor? sup;
      try {
        sup = supervisores.firstWhere(
          (s) => s.nombre.toLowerCase().contains(nombre) && s.codigo == codigo,
        );
      } catch (_) {}

      // Buscar en vendedores
      Vendedor? ven;
      if (sup == null) {
        try {
          ven = vendedores.firstWhere(
            (v) => v.nombre.toLowerCase().contains(nombre) && v.codigo == codigo,
          );
        } catch (_) {}
      }

      if (sup == null && ven == null) {
        if (mounted) {
          setState(() => _loading = false);
          await ArtSweetAlert.show(
            context: context,
            title: const Text('Credenciales incorrectas'),
            content: const Text('No se encontró ningún usuario con ese nombre y código. Verifique sus datos o contacte al administrador.'),
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
            // Ambient glow top-right
            Positioned(
              top: -120,
              right: -100,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.white.withOpacity(0.035), Colors.transparent],
                  ),
                ),
              ),
            ),
            // Ambient glow bottom-left
            Positioned(
              bottom: -100,
              left: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.white.withOpacity(0.025), Colors.transparent],
                  ),
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
                      // ── Logo Oral-Plus directo ─────────────────────
                      Image.asset(
                        'assets/images/LOGO 2 1 (2).png',
                        height: 90,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.schedule_rounded,
                          size: 52,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'MINUTO A MINUTO',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Seguimiento · PPVC · RVC',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.3),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── API Status Badge ─────────────────────────
                      _ApiStatusChip(estado: _conexion),
                      const SizedBox(height: 40),

                      // ── Login Card ───────────────────────────────
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131313),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white.withOpacity(0.07)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 50,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Header card
                                Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
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
                                        const Text(
                                          'Iniciar Sesión',
                                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                                        ),
                                        Text(
                                          'Ingresa tu nombre y código',
                                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),

                                // Campo nombre
                                _DarkField(
                                  controller: _nombreCtrl,
                                  label: 'Nombre',
                                  hint: 'Ej: Juan Pérez',
                                  prefixIcon: Icons.person_outline_rounded,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                                  textCapitalization: TextCapitalization.words,
                                ),
                                const SizedBox(height: 14),

                                // Campo código (PIN)
                                _DarkField(
                                  controller: _codigoCtrl,
                                  label: 'Código',
                                  hint: 'Ej: S001',
                                  prefixIcon: Icons.pin_outlined,
                                  obscureText: !_showCodigo,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showCodigo ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: Colors.white30,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _showCodigo = !_showCodigo),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu código' : null,
                                ),
                                const SizedBox(height: 24),

                                // Botón ingresar
                                _PremiumButton(
                                  label: _loading ? 'Verificando...' : 'Ingresar',
                                  enabled: !_loading,
                                  loading: _loading,
                                  onPressed: () => _login(context),
                                ),
                                const SizedBox(height: 14),
                                TextButton(
                                  onPressed: () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => const SetupScreen()),
                                  ),
                                  child: Text(
                                    'Configurar equipo →',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.28),
                                      fontSize: 13,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dark Text Field ─────────────────────────────────────────────────────────

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

// ── API Status Chip ──────────────────────────────────────────────────────────

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
    final isOk = widget.estado == _ConexionEstado.conectado;

    final Color dotColor = isChecking ? Colors.white38 : isOk ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
    final String label = isChecking ? 'Verificando conexión...' : isOk ? 'API conectada' : 'Sin conexión al servidor';
    final IconData icon = isChecking ? Icons.compare_arrows_rounded : isOk ? Icons.cloud_done_outlined : Icons.cloud_off_outlined;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isChecking ? Colors.white12 : isOk ? const Color(0xFF4CAF50).withOpacity(0.3) : const Color(0xFFE53935).withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isChecking)
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white38,
                ),
              )
            else
              Opacity(
                opacity: 0.5 + _pulse.value * 0.5,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
              ),
            const SizedBox(width: 8),
            Icon(icon, size: 14, color: isChecking ? Colors.white38 : isOk ? const Color(0xFF66BB6A) : const Color(0xFFEF5350)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isChecking ? Colors.white38 : isOk ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Premium Button ────────────────────────────────────────────────────────────

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
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                ),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: enabled ? Colors.black : Colors.white30,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
