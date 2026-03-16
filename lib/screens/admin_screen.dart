import 'package:flutter/material.dart';
import '../models/supervisor.dart';
import '../models/vendedor.dart';
import '../services/data_service.dart';
import '../utils/constants.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_loading_screen.dart';
import 'registro_supervisor_screen.dart';
import 'registro_vendedor_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Supervisor> _supervisores = [];
  List<Vendedor> _vendedores = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);
    try {
      final sp = await DataService.getSupervisores().timeout(
        const Duration(seconds: 20),
        onTimeout: () => <Supervisor>[],
      );
      final vd = await DataService.getVendedores().timeout(
        const Duration(seconds: 20),
        onTimeout: () => <Vendedor>[],
      );
      if (!mounted) return;
      setState(() {
        _supervisores = sp;
        _vendedores = vd;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarSupervisor(Supervisor s) async {
    final ok = await AppFeedback.confirmDialog(
      context,
      title: 'Eliminar supervisor',
      message: 'Se eliminará a ${s.nombre} (${s.cargo.displayName}). Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      confirmColor: AppConstants.rojoCritico,
      icon: Icons.delete_outline_rounded,
    );

    if (!ok) return;
    try {
      await DataService.deleteSupervisor(s.id);
      await _cargar();
      if (!mounted) return;
      AppFeedback.success(context, 'Supervisor eliminado');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Error al eliminar: $e');
    }
  }

  Future<void> _eliminarVendedor(Vendedor v) async {
    final ok = await AppFeedback.confirmDialog(
      context,
      title: 'Eliminar vendedor',
      message: 'Se eliminará a ${v.nombre}. Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      confirmColor: AppConstants.rojoCritico,
      icon: Icons.delete_outline_rounded,
    );

    if (!ok) return;
    try {
      await DataService.deleteVendedor(v.id);
      await _cargar();
      if (!mounted) return;
      AppFeedback.success(context, 'Vendedor eliminado');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Error al eliminar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const AppLoadingScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Administracion de Equipo'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        actions: [
          IconButton(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: _ResumenAdmin(
                    totalSupervisores: _supervisores.length,
                    totalVendedores: _vendedores.length,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppConstants.azulCorporativo,
                      labelColor: AppConstants.azulCorporativo,
                      unselectedLabelColor: Colors.black54,
                      tabs: const [
                        Tab(
                          text: 'Supervisores',
                          icon: Icon(Icons.supervisor_account_rounded, size: 20),
                        ),
                        Tab(
                          text: 'Vendedores',
                          icon: Icon(Icons.storefront_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _ListaSupervisores(
                        lista: _supervisores,
                        onRefrescar: _cargar,
                        onEliminar: _eliminarSupervisor,
                        onAgregar: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegistroSupervisorScreen(),
                            ),
                          );
                          _cargar();
                        },
                      ),
                      _ListaVendedores(
                        lista: _vendedores,
                        coaches: _supervisores.where((s) => s.esCoach).toList(),
                        onRefrescar: _cargar,
                        onEliminar: _eliminarVendedor,
                        onAgregar: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegistroVendedorScreen(),
                            ),
                          );
                          _cargar();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ResumenAdmin extends StatelessWidget {
  final int totalSupervisores;
  final int totalVendedores;

  const _ResumenAdmin({
    required this.totalSupervisores,
    required this.totalVendedores,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.black87, Colors.black54],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$totalSupervisores supervisores - $totalVendedores vendedores',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaSupervisores extends StatelessWidget {
  final List<Supervisor> lista;
  final VoidCallback onAgregar;
  final void Function(Supervisor) onEliminar;
  final Future<void> Function() onRefrescar;

  const _ListaSupervisores({
    required this.lista,
    required this.onAgregar,
    required this.onEliminar,
    required this.onRefrescar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAgregar,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar supervisor'),
              style: FilledButton.styleFrom(
                backgroundColor: AppConstants.azulCorporativo,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: lista.isEmpty
              ? const AppEmptyState(
                  icon: Icons.supervisor_account_outlined,
                  title: 'No hay supervisores registrados',
                )
              : RefreshIndicator(
                  onRefresh: onRefrescar,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: lista.length,
                    itemBuilder: (_, i) {
                      final s = lista[i];
                      return _SupervisorTile(s: s, onEliminar: onEliminar);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _ListaVendedores extends StatelessWidget {
  final List<Vendedor> lista;
  final List<Supervisor> coaches;
  final VoidCallback onAgregar;
  final void Function(Vendedor) onEliminar;
  final Future<void> Function() onRefrescar;

  const _ListaVendedores({
    required this.lista,
    required this.coaches,
    required this.onAgregar,
    required this.onEliminar,
    required this.onRefrescar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: coaches.isEmpty ? null : onAgregar,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar vendedor'),
              style: FilledButton.styleFrom(
                backgroundColor: AppConstants.azulCorporativo,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        if (coaches.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'Primero registra al menos un Coach para crear vendedores.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ),
        Expanded(
          child: lista.isEmpty
              ? const AppEmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No hay vendedores registrados',
                )
              : RefreshIndicator(
                  onRefresh: onRefrescar,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: lista.length,
                    itemBuilder: (_, i) {
                      final v = lista[i];
                      String? coachNombre;
                      for (final c in coaches) {
                        if (c.id == v.coachId) {
                          coachNombre = c.nombre;
                          break;
                        }
                      }
                      return _VendedorTile(
                        v: v,
                        coachNombre: coachNombre,
                        onEliminar: onEliminar,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _SupervisorTile extends StatelessWidget {
  final Supervisor s;
  final void Function(Supervisor) onEliminar;

  const _SupervisorTile({required this.s, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: AppConstants.azulCorporativo.withValues(alpha: 0.12),
          child: Text(
            s.cargo.displayName[0],
            style: const TextStyle(
              color: AppConstants.azulCorporativo,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          s.nombre,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${s.codigo} Â· ${s.zona} Â· ${s.cargo.displayName}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          onPressed: () => onEliminar(s),
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: AppConstants.rojoCritico,
          ),
        ),
      ),
    );
  }
}

class _VendedorTile extends StatelessWidget {
  final Vendedor v;
  final String? coachNombre;
  final void Function(Vendedor) onEliminar;

  const _VendedorTile({
    required this.v,
    required this.coachNombre,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: AppConstants.verdeMeta.withValues(alpha: 0.12),
          child: const Icon(Icons.person_rounded, color: AppConstants.verdeMeta),
        ),
        title: Text(
          v.nombre,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${v.codigo} Â· ${v.zona}${coachNombre != null ? ' Â· Coach: $coachNombre' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          onPressed: () => onEliminar(v),
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: AppConstants.rojoCritico,
          ),
        ),
      ),
    );
  }
}

