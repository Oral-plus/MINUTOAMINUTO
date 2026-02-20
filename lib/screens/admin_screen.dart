import 'package:flutter/material.dart';
import '../models/supervisor.dart';
import '../models/vendedor.dart';
import '../services/data_service.dart';
import '../utils/constants.dart';
import 'registro_supervisor_screen.dart';
import 'registro_vendedor_screen.dart';

/// Pantalla para administrar supervisores y vendedores.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
    setState(() => _cargando = true);
    final sp = await DataService.getSupervisores();
    final vd = await DataService.getVendedores();
    setState(() {
      _supervisores = sp;
      _vendedores = vd;
      _cargando = false;
    });
  }

  Future<void> _eliminarSupervisor(Supervisor s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar supervisor'),
        content: Text('¿Eliminar a ${s.nombre} (${s.cargo.displayName})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppConstants.rojoCritico),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await DataService.deleteSupervisor(s.id);
        await _cargar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Supervisor eliminado'), backgroundColor: AppConstants.verdeMeta),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: AppConstants.rojoCritico),
          );
        }
      }
    }
  }

  Future<void> _eliminarVendedor(Vendedor v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar vendedor'),
        content: Text('¿Eliminar a ${v.nombre}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppConstants.rojoCritico),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await DataService.deleteVendedor(v.id);
        await _cargar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vendedor eliminado'), backgroundColor: AppConstants.verdeMeta),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: AppConstants.rojoCritico),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar equipo'),
        backgroundColor: AppConstants.azulCorporativo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          tabs: const [
            Tab(text: 'Supervisores', icon: Icon(Icons.supervisor_account, size: 20)),
            Tab(text: 'Vendedores', icon: Icon(Icons.storefront, size: 20)),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _ListaSupervisores(
                  lista: _supervisores,
                  onAgregar: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegistroSupervisorScreen()),
                    );
                    _cargar();
                  },
                  onEliminar: _eliminarSupervisor,
                ),
                _ListaVendedores(
                  lista: _vendedores,
                  coaches: _supervisores.where((s) => s.esCoach).toList(),
                  onAgregar: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegistroVendedorScreen()),
                    );
                    _cargar();
                  },
                  onEliminar: _eliminarVendedor,
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

  const _ListaSupervisores({
    required this.lista,
    required this.onAgregar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAgregar,
              icon: const Icon(Icons.add),
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
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.supervisor_account_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('Sin supervisores', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final s = lista[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppConstants.azulCorporativo.withOpacity(0.2),
                          child: Text(s.cargo.displayName[0], style: const TextStyle(color: AppConstants.azulCorporativo)),
                        ),
                        title: Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${s.codigo} · ${s.zona} · ${s.cargo.displayName}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppConstants.rojoCritico),
                          onPressed: () => onEliminar(s),
                        ),
                      ),
                    );
                  },
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

  const _ListaVendedores({
    required this.lista,
    required this.coaches,
    required this.onAgregar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: coaches.isEmpty ? null : onAgregar,
              icon: const Icon(Icons.add),
              label: const Text('Agregar vendedor'),
              style: FilledButton.styleFrom(
                backgroundColor: AppConstants.azulCorporativo,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        if (coaches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Agregue al menos un Coach antes de registrar vendedores.', style: TextStyle(color: Colors.grey[600])),
          ),
        Expanded(
          child: lista.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('Sin vendedores', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final v = lista[i];
                    final coachList = coaches.where((c) => c.id == v.coachId).toList();
                    final coach = coachList.isNotEmpty ? coachList.first : null;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppConstants.verdeMeta.withOpacity(0.2),
                          child: const Icon(Icons.person, color: AppConstants.verdeMeta),
                        ),
                        title: Text(v.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${v.codigo} · ${v.zona}${coach != null ? ' · Coach: ${coach.nombre}' : ''}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppConstants.rojoCritico),
                          onPressed: () => onEliminar(v),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
