import '../utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class BloqueVendedoresSap extends StatelessWidget {
  const BloqueVendedoresSap({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final vendedores = provider.vendedoresSap;
        if (vendedores.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.groups_rounded, color: context.ac.fgSubtle, size: 16),
                  SizedBox(width: 8),
                  Text(
                     'MI EQUIPO (SAP)',
                    style: TextStyle(
                      color: context.ac.fg.withOpacity(0.3),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: context.ac.surfaceAlt,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: context.ac.fg.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: context.ac.fg.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: vendedores.length,
                separatorBuilder: (_, _) => Divider(
                  color: context.ac.fg.withOpacity(0.04),
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final nombre = vendedores[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: context.ac.fg.withOpacity(0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: context.ac.fg.withOpacity(0.05)),
                      ),
                      child: Icon(Icons.person_rounded, color: context.ac.fgSubtle, size: 20),
                    ),
                    title: Text(
                      nombre,
                      style: TextStyle(
                        color: context.ac.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Vendedor: $nombre'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: context.ac.fg,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
