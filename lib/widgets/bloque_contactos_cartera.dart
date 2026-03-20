import '../utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/contacto_cartera.dart';

/// Bloque del dashboard que muestra los clientes SAP que el usuario debe contactar,
/// filtrados según su cargo (COACH, KAM o Jefe de Ventas).
class BloqueContactosCartera extends StatelessWidget {
  const BloqueContactosCartera({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final contactos = provider.contactosCartera;
        final cargo = provider.usuarioActual?.cargo.displayName ?? 'Vendedor';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.ac.fg.withOpacity(0.07)),
            boxShadow: [
              BoxShadow(
                color: context.ac.fg.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.ac.fg.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.people_alt_rounded,
                      color: context.ac.fg.withOpacity(0.7),
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A QUIÉN LLAMAR',
                          style: TextStyle(
                            color: context.ac.fg,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'Cartera de $cargo • ${contactos.length} contactos',
                          style: TextStyle(
                            color: context.ac.fg.withOpacity(0.35),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Botón refrescar
                  IconButton(
                    onPressed: () => context.read<AppProvider>().recargarDashboard(),
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: context.ac.fg.withOpacity(0.3),
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),

              if (contactos.isEmpty) ...[
                SizedBox(height: 20),
                _EmptyState(),
              ] else ...[
                SizedBox(height: 16),
                // Lista de contactos
                ...contactos.take(50).map((c) => _ContactoTile(contacto: c)),
                if (contactos.length > 50)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '+ ${contactos.length - 50} más en cartera',
                      style: TextStyle(
                        color: context.ac.fg.withOpacity(0.25),
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 40, color: context.ac.fg.withOpacity(0.1)),
          SizedBox(height: 10),
          Text(
            'Cargando contactos de SAP...',
            style: TextStyle(
              color: context.ac.fg.withOpacity(0.25),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactoTile extends StatelessWidget {
  final ContactoCartera contacto;
  const _ContactoTile({required this.contacto});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.ac.fg.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.ac.fg.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          // Avatar inicial
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.ac.fg.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              contacto.nombreMostrar.isNotEmpty
                  ? contacto.nombreMostrar[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: context.ac.fg,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contacto.nombreMostrar,
                  style: TextStyle(
                    color: context.ac.fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  'Vendedor: ${contacto.slpName}',
                  style: TextStyle(
                    color: context.ac.fg.withOpacity(0.35),
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Chips Coach / KAM
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (contacto.coach.isNotEmpty)
                _Chip(label: contacto.coach, icon: Icons.sports_rounded),
              if (contacto.kam.isNotEmpty)
                _Chip(label: contacto.kam, icon: Icons.badge_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Chip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: context.ac.fg.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: context.ac.fg.withOpacity(0.35)),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: context.ac.fg.withOpacity(0.45),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
