import 'package:flutter/material.dart';

import '../core/device_registry.dart';
import '../core/models/device.dart';
import '../core/models/diagnostics.dart';

/// "Información del dispositivo": detalles técnicos sin secretos.
class DeviceInfoScreen extends StatelessWidget {
  const DeviceInfoScreen(
      {super.key, required this.registry, required this.device});

  final DeviceRegistry registry;
  final Device device;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Información del dispositivo')),
      body: FutureBuilder<List<DiagnosticsSection>>(
        future: registry.diagnostics(device.id),
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

class DiagnosticsView extends StatelessWidget {
  const DiagnosticsView({super.key, required this.sections});

  final List<DiagnosticsSection> sections;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final s in sections)
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(s.title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final e in s.entries)
                  ListTile(
                    dense: true,
                    title: Text(e.label),
                    subtitle: SelectableText(e.value),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
