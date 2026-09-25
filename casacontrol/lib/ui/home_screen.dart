import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/device_registry.dart';
import '../core/models/capability.dart';
import '../core/models/command.dart';
import '../core/models/device.dart';
import 'device_control_screen.dart';
import 'labels.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final registry = controller.registry;
        return ListenableBuilder(
          listenable: registry,
          builder: (context, _) => Scaffold(
            appBar: AppBar(
              title: const Text('Casa'),
              actions: [
                if (controller.demoMode)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Chip(label: Text('Demo')),
                  ),
                IconButton(
                  tooltip: 'Configuración',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsScreen(controller: controller),
                    ),
                  ),
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: registry.refresh,
              child: _DeviceList(registry: registry),
            ),
          ),
        );
      },
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.registry});

  final DeviceRegistry registry;

  @override
  Widget build(BuildContext context) {
    final devices = registry.devices;
    if (devices.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.home_outlined, size: 64),
          const SizedBox(height: 16),
          Text(
            'Buscando dispositivos…',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Yeelight: la ampolleta debe estar en la misma red Wi-Fi y con '
            '"Control LAN" activado en la app Yeelight.\n'
            'Tuya: iniciá sesión desde Configuración.\n'
            'También podés activar el Modo Demo en Configuración.',
            textAlign: TextAlign.center,
          ),
          for (final e in registry.startErrors.entries)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('${e.key}: ${e.value}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      );
    }
    final byRoom = <String, List<Device>>{};
    for (final d in devices) {
      byRoom.putIfAbsent(d.room ?? 'Sin habitación', () => []).add(d);
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final room in byRoom.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(room.key,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final d in room.value) DeviceCard(registry: registry, device: d),
        ],
      ],
    );
  }
}

class DeviceCard extends StatelessWidget {
  const DeviceCard({super.key, required this.registry, required this.device});

  final DeviceRegistry registry;
  final Device device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = device.state.power == true;
    final accent = device.state.mode == LightMode.color &&
            device.state.color != null &&
            on
        ? colorFromHsv(device.state.color!)
        : theme.colorScheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) =>
              DeviceControlScreen(registry: registry, deviceId: device.id),
        )),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: on
                    ? accent.withValues(alpha: 0.2)
                    : theme.colorScheme.surfaceContainerHighest,
                child: Icon(deviceIcon(device),
                    color: on ? accent : theme.disabledColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: theme.textTheme.titleMedium),
                    Text(stateLines(device).join(' · ')),
                    const SizedBox(height: 4),
                    ConnectivityBadge(device: device),
                  ],
                ),
              ),
              if (device.capabilities.has<PowerCapability>())
                Switch(
                  value: on,
                  onChanged: device.online
                      ? (v) => runCommand(
                          context, registry, device.id, SetPower(v))
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectivityBadge extends StatelessWidget {
  const ConnectivityBadge({super.key, required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle,
            size: 10, color: device.online ? Colors.green : Colors.grey),
        const SizedBox(width: 4),
        Text(device.online ? 'En línea' : 'Sin conexión', style: style),
        Text('  ·  ${device.connectivity.label}', style: style),
      ],
    );
  }
}

/// Ejecuta una orden mostrando el error en un SnackBar si falla.
Future<void> runCommand(BuildContext context, DeviceRegistry registry,
    String deviceId, DeviceCommand command) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await registry.execute(deviceId, command);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('No se pudo: $e')));
  }
}
