import '../utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class BloqueEquipoJerarquico extends StatefulWidget {
  const BloqueEquipoJerarquico({super.key});

  @override
  State<BloqueEquipoJerarquico> createState() => _BloqueEquipoJerarquicoState();
}

class _BloqueEquipoJerarquicoState extends State<BloqueEquipoJerarquico> {
  String? _kamSelected;
  String? _coachSelected;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final jerarquia = provider.equipoJerarquico;
        if (jerarquia.isEmpty) return const SizedBox.shrink();

        final sup = provider.usuarioActual;
        if (sup != null) {
          // Auto-seleccion para KAM
          if (sup.esKam && _kamSelected == null) {
            final match = jerarquia.any((k) => k['nombre'] == sup.nombre);
            if (match) _kamSelected = sup.nombre;
          }
          // Auto-seleccion para COACH
          if (sup.esCoach && _coachSelected == null) {
            for (var kam in jerarquia) {
              final coaches = kam['coaches'] as List<dynamic>;
              final hasCoach = coaches.any((c) => c['nombre'] == sup.nombre);
              if (hasCoach) {
                _kamSelected = kam['nombre'];
                _coachSelected = sup.nombre;
                break;
              }
            }
          }
        }

        // Si es KAM o COACH, restringir la lista a su propio nivel
        final kamItems = (sup?.esKam ?? false) && _kamSelected != null
            ? [_kamSelected!] 
            : (sup?.esCoach ?? false) && _kamSelected != null
                ? [_kamSelected!]
                : jerarquia.map((k) => k['nombre'] as String).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('CONTROL JERÁRQUICO (SAP)', Icons.account_tree_rounded),
            SizedBox(height: 8),
            
            // Selector de KAM
            _buildSelector(
              label: 'KAM',
              value: _kamSelected,
              items: kamItems,
              onChanged: (sup?.esKam ?? false) || (sup?.esCoach ?? false) ? null : (val) {
                setState(() {
                  _kamSelected = val;
                  _coachSelected = null;
                });
              },
            ),

            if (_kamSelected != null) ...[
              SizedBox(height: 12),
              // Selector de COACH
              _buildSelector(
                label: 'COACH',
                value: _coachSelected,
                items: (sup?.esCoach ?? false) 
                    ? [_coachSelected!] 
                    : _getCoachesForKam(jerarquia, _kamSelected!),
                onChanged: (sup?.esCoach ?? false) ? null : (val) {
                  setState(() {
                    _coachSelected = val;
                  });
                },
              ),
            ],

            if (_coachSelected != null) ...[
              SizedBox(height: 16),
              _buildListaVendedores(jerarquia, _kamSelected!, _coachSelected!),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: context.ac.fgSubtle, size: 16),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: context.ac.fg.withOpacity(0.3),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelector({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.ac.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.ac.fg.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text('Seleccionar $label', style: TextStyle(color: context.ac.fgSubtle, fontSize: 14)),
          dropdownColor: context.ac.surface,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.ac.fgSubtle),
          items: items.map((e) => DropdownMenuItem(
            value: e,
            child: Text(e, style: TextStyle(color: context.ac.fg, fontSize: 14)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  List<String> _getCoachesForKam(List<dynamic> jerarquia, String kamName) {
    final kam = jerarquia.firstWhere((k) => k['nombre'] == kamName, orElse: () => null);
    if (kam == null) return [];
    return (kam['coaches'] as List<dynamic>).map((c) => c['nombre'] as String).toList();
  }

  Widget _buildListaVendedores(List<dynamic> jerarquia, String kamName, String coachName) {
    final kam = jerarquia.firstWhere((k) => k['nombre'] == kamName, orElse: () => null);
    if (kam == null) return const SizedBox.shrink();
    
    final coach = (kam['coaches'] as List<dynamic>).firstWhere((c) => c['nombre'] == coachName, orElse: () => null);
    if (coach == null) return const SizedBox.shrink();

    final vendedores = coach['vendedores'] as List<dynamic>;

    return Container(
      decoration: BoxDecoration(
        color: context.ac.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.ac.fg.withOpacity(0.08)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: vendedores.length,
        separatorBuilder: (_, _) => Divider(color: context.ac.fg.withOpacity(0.04), height: 1),
        itemBuilder: (context, index) {
          final v = vendedores[index];
          final calls = v['llamadas'] as int;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(v['nombre'], style: TextStyle(color: context.ac.fg, fontSize: 14, fontWeight: FontWeight.bold)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: calls > 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$calls llamadas',
                style: TextStyle(
                  color: calls > 0 ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
