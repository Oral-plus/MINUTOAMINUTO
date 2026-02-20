import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import '../widgets/bloque_disciplina.dart';
import '../widgets/bloque_productividad.dart';
import '../widgets/bloque_ppvc_rvc.dart';
import '../widgets/bloque_control_jerarquico.dart';
import '../widgets/bloque_alertas.dart';
import '../widgets/bloque_ranking.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Minuto a Minuto'),
        backgroundColor: AppConstants.azulCorporativo,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<AppProvider>().init();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BloqueDisciplina(),
              const SizedBox(height: 16),
              const BloqueProductividad(),
              const SizedBox(height: 16),
              const BloquePpvcRvc(),
              const SizedBox(height: 16),
              const BloqueControlJerarquico(),
              const SizedBox(height: 16),
              const BloqueAlertas(),
              const SizedBox(height: 16),
              const BloqueRanking(),
            ],
          ),
        ),
      ),
    );
  }
}
