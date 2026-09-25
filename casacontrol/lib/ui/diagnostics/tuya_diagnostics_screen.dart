import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/models/diagnostics.dart';
import '../device_info_screen.dart';

/// Diagnóstico Tuya: para cada dispositivo muestra PID, categoría,
/// comunicación, capacidades y Data Points reales, sin secretos.
/// Es la herramienta de la Fase 4 para llenar docs/DEVICE_INTEGRATION.md.
class TuyaDiagnosticsScreen extends StatelessWidget {
  const TuyaDiagnosticsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final tuya = controller.tuya;
    final String? problem = switch (tuya) {
      null => 'Desactivá el Modo Demo para usar Tuya.',
      _ when !tuya.configured =>
        'Este APK se compiló sin el SDK de Tuya. Ver docs/TUYA_SETUP.md.',
      _ when !tuya.loggedIn => 'Iniciá sesión con la cuenta de CasaControl.',
      _ => null,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico Tuya')),
      body: problem != null
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24), child: Text(problem)))
          : FutureBuilder<List<DiagnosticsSection>>(
              future: () async {
                await tuya!.refresh();
                final sections = <DiagnosticsSection>[
                  DiagnosticsSection('SDK', [
                    DiagnosticsEntry('Versión', tuya.sdkVersion ?? '—'),
                    DiagnosticsEntry('Dispositivos',
                        '${tuya.currentDevices.length}'),
                  ]),
                ];
                for (final d in tuya.currentDevices) {
                  final ds = await tuya.diagnostics(d.id);
                  sections.addAll([
                    for (final s in ds)
                      DiagnosticsSection('${d.name} — ${s.title}', s.entries),
                  ]);
                }
                return sections;
              }(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return DiagnosticsView(sections: snap.data!);
              },
            ),
    );
  }
}
