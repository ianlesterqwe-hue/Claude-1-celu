import 'dart:async';

import 'package:flutter/foundation.dart';

import 'adapters/device_adapter.dart';
import 'models/command.dart';
import 'models/device.dart';
import 'models/diagnostics.dart';

/// Une todos los adaptadores en una única lista de dispositivos para la UI.
class DeviceRegistry extends ChangeNotifier {
  DeviceRegistry(this.adapters);

  final List<DeviceAdapter> adapters;
  final Map<String, List<Device>> _byAdapter = {};
  final Map<String, String> _startErrors = {};
  final List<StreamSubscription<List<Device>>> _subs = [];

  /// Errores al iniciar un adaptador (p. ej. Tuya no configurado).
  Map<String, String> get startErrors => Map.unmodifiable(_startErrors);

  List<Device> get devices =>
      [for (final a in adapters) ...?_byAdapter[a.id]];

  Device? byId(String id) {
    for (final d in devices) {
      if (d.id == id) return d;
    }
    return null;
  }

  DeviceAdapter adapterFor(String deviceId) {
    final prefix = deviceId.split(':').first;
    return adapters.firstWhere(
      (a) => a.id == prefix,
      orElse: () => throw ArgumentError('Sin adaptador para $deviceId'),
    );
  }

  Future<void> start() async {
    for (final adapter in adapters) {
      _subs.add(adapter.devices.listen((list) {
        _byAdapter[adapter.id] = list;
        notifyListeners();
      }));
      try {
        await adapter.start();
        _startErrors.remove(adapter.id);
      } catch (e) {
        _startErrors[adapter.id] = e.toString();
      }
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await Future.wait(adapters.map((a) async {
      try {
        await a.refresh();
      } catch (e) {
        _startErrors[a.id] = e.toString();
      }
    }));
    notifyListeners();
  }

  Future<void> execute(String deviceId, DeviceCommand command) =>
      adapterFor(deviceId).execute(deviceId, command);

  Future<List<DiagnosticsSection>> diagnostics(String deviceId) =>
      adapterFor(deviceId).diagnostics(deviceId);

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    for (final a in adapters) {
      a.dispose();
    }
    super.dispose();
  }
}
