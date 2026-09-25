import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/adapters/device_adapter.dart';
import '../../core/models/capability.dart';
import '../../core/models/command.dart';
import '../../core/models/device.dart';
import '../../core/models/diagnostics.dart';
import 'tuya_dp_mapper.dart';
import 'tuya_platform.dart';

/// Tipo de comunicación informado por la capa nativa.
enum TuyaCommunication {
  wifi('Wi-Fi'),
  ble('BLE punto a punto'),
  tuyaMesh('Tuya Bluetooth Mesh'),
  sigMesh('Bluetooth SIG Mesh'),
  beacon('Tuya Beacon'),
  wifiBleCombo('Wi-Fi + Bluetooth'),
  unknown('Desconocido');

  const TuyaCommunication(this.label);
  final String label;

  static TuyaCommunication parse(Object? s) => switch (s) {
        'wifi' => wifi,
        'ble' => ble,
        'mesh' => tuyaMesh,
        'sigmesh' => sigMesh,
        'beacon' => beacon,
        'combo' => wifiBleCombo,
        _ => unknown,
      };

  bool get isBluetooth =>
      this == ble || this == tuyaMesh || this == sigMesh || this == beacon;
}

class TuyaNotConfiguredException implements Exception {
  @override
  String toString() =>
      'Tuya no está configurado en esta compilación (ver docs/TUYA_SETUP.md).';
}

class TuyaNotLoggedInException implements Exception {
  @override
  String toString() => 'Iniciá sesión con tu cuenta de CasaControl (Tuya).';
}

class _TuyaDevice {
  _TuyaDevice(this.raw)
      : mapping = TuyaDpMapping.fromSchema(
          [
            for (final s in (raw['schema'] as List?) ?? const [])
              DpSchema.fromMap((s as Map).cast<Object?, Object?>()),
          ],
          category: raw['category']?.toString(),
        ),
        dps = {
          for (final e in ((raw['dps'] as Map?) ?? const {}).entries)
            e.key.toString(): e.value,
        },
        online = raw['online'] == true,
        localOnline = raw['localOnline'] == true;

  final Map<Object?, Object?> raw;
  final TuyaDpMapping mapping;
  final Map<String, Object?> dps;
  bool online;
  bool localOnline;

  String get devId => raw['devId'].toString();
  String get name => raw['name']?.toString() ?? 'Dispositivo Tuya';
  TuyaCommunication get communication =>
      TuyaCommunication.parse(raw['communication']);

  Connectivity get connectivity {
    if (communication.isBluetooth) return Connectivity.bluetooth;
    if (communication == TuyaCommunication.wifi ||
        communication == TuyaCommunication.wifiBleCombo) {
      return localOnline ? Connectivity.tuyaCloudLan : Connectivity.tuyaCloud;
    }
    return Connectivity.unknown;
  }

  Device toDevice() => Device(
        id: 'tuya:$devId',
        adapterId: 'tuya',
        name: name,
        room: raw['roomName']?.toString(),
        model: raw['productName']?.toString(),
        kind: mapping.kind,
        capabilities: [
          ...mapping.capabilities,
          // Los timers de nube del SDK aplican a dispositivos Wi-Fi.
          // Para Bluetooth/Beacon se confirmará en la Fase 9.
          if (!communication.isBluetooth &&
              mapping.capabilities.has<PowerCapability>())
            const ScheduleCapability(),
        ],
        state: mapping.decodeState(dps),
        online: online,
        connectivity: connectivity,
      );
}

/// Adaptador Dart para Tuya. Toda la lógica del SDK vive en Kotlin
/// (TuyaPlatformService); aquí sólo se mapean DPs ↔ capacidades.
class TuyaAdapter implements DeviceAdapter {
  TuyaAdapter({TuyaPlatform? platform})
      : platform = platform ?? TuyaPlatform();

  final TuyaPlatform platform;
  final _controller = StreamController<List<Device>>.broadcast();
  final _devices = <String, _TuyaDevice>{};
  StreamSubscription<Map<Object?, Object?>>? _eventsSub;

  bool configured = false;
  bool loggedIn = false;
  int? currentHomeId;
  String? sdkVersion;

  @override
  String get id => 'tuya';

  @override
  String get displayName => 'Tuya';

  @override
  Stream<List<Device>> get devices => _controller.stream;

  @override
  List<Device> get currentDevices =>
      [for (final d in _devices.values) d.toDevice()];

  @override
  Future<void> start() async {
    try {
      final info = await platform.initialize();
      configured = info['configured'] == true;
      sdkVersion = info['sdkVersion']?.toString();
    } on MissingPluginException {
      configured = false;
    }
    if (!configured) throw TuyaNotConfiguredException();
    _eventsSub ??= platform.subscribeDeviceState().listen(_onEvent);
    loggedIn = await platform.isLoggedIn();
    if (!loggedIn) throw TuyaNotLoggedInException();
    await refresh();
  }

  Future<void> login(String countryCode, String email, String password) async {
    await platform.login(countryCode, email, password);
    loggedIn = true;
    await refresh();
  }

  @override
  Future<void> refresh() async {
    if (!configured || !loggedIn) return;
    final homes = await platform.getHomes();
    if (homes.isEmpty) {
      _devices.clear();
      _emit();
      return;
    }
    currentHomeId ??= (homes.first['homeId'] as num).toInt();
    final list = await platform.getDevices(currentHomeId!);
    _devices
      ..clear()
      ..addEntries(list.map((m) {
        final d = _TuyaDevice(m);
        return MapEntry(d.devId, d);
      }));
    _emit();
  }

  void _onEvent(Map<Object?, Object?> e) {
    final dev = _devices[e['devId']?.toString()];
    if (dev == null) return;
    switch (e['type']) {
      case 'dpUpdate':
        final dps = (e['dps'] as Map?) ?? const {};
        for (final entry in dps.entries) {
          dev.dps[entry.key.toString()] = entry.value;
        }
      case 'online':
        dev.online = e['online'] == true;
        if (e['localOnline'] != null) dev.localOnline = e['localOnline'] == true;
      case 'removed':
        _devices.remove(dev.devId);
      case 'infoUpdate':
        unawaited(refresh());
        return;
    }
    _emit();
  }

  _TuyaDevice _dev(String deviceId) {
    final d = _devices[deviceId.substring(id.length + 1)];
    if (d == null) throw DeviceCommandException('Dispositivo no encontrado');
    return d;
  }

  @override
  Future<void> execute(String deviceId, DeviceCommand command) async {
    final dev = _dev(deviceId);
    final Map<String, Object> dps;
    try {
      dps = dev.mapping.encode(command, dev.mapping.decodeState(dev.dps));
    } on UnsupportedError catch (e) {
      throw DeviceCommandException(
          'El dispositivo no expone ${e.message ?? 'esa función'}');
    }
    try {
      if (dev.communication.isBluetooth) {
        await platform.connectDevice(dev.devId);
      }
      await platform.publishDataPoints(dev.devId, dps);
      // Optimista; el SDK confirma con un evento dpUpdate.
      dev.dps.addAll(dps);
      _emit();
    } on PlatformException catch (e) {
      throw DeviceCommandException(e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<List<DiagnosticsSection>> diagnostics(String deviceId) async {
    final dev = _dev(deviceId);
    final device = dev.toDevice();
    final caps = device.capabilities;
    String check(bool ok) => ok ? '✓' : '✗';
    return [
      DiagnosticsSection('Tuya', [
        DiagnosticsEntry('Nombre', dev.name),
        DiagnosticsEntry('Device ID', redactId(dev.devId)),
        DiagnosticsEntry('Product ID', dev.raw['productId']?.toString() ?? '—'),
        DiagnosticsEntry('Categoría', dev.raw['category']?.toString() ?? '—'),
        DiagnosticsEntry('Estado', dev.online ? 'En línea' : 'Sin conexión'),
        DiagnosticsEntry('Comunicación', dev.communication.label),
        if (dev.raw['bleType'] != null)
          DiagnosticsEntry('Tipo Bluetooth', dev.raw['bleType'].toString()),
        DiagnosticsEntry('Control local', dev.localOnline ? 'Sí' : 'No'),
      ]),
      DiagnosticsSection('Capacidades', [
        DiagnosticsEntry('Encendido', check(caps.has<PowerCapability>())),
        DiagnosticsEntry('Brillo', check(caps.has<BrightnessCapability>())),
        DiagnosticsEntry('RGB', check(caps.has<ColorCapability>())),
        DiagnosticsEntry('Temperatura de color',
            check(caps.has<ColorTemperatureCapability>())),
        DiagnosticsEntry('Temporizador', check(caps.has<CountdownCapability>())),
        DiagnosticsEntry('Medición eléctrica',
            check(caps.has<EnergyMeterCapability>())),
      ]),
      DiagnosticsSection('Data Points', [
        for (final s in dev.mapping.schema.values.toList()
          ..sort((a, b) =>
              (int.tryParse(a.id) ?? 0).compareTo(int.tryParse(b.id) ?? 0)))
          DiagnosticsEntry(
            'DP ${s.id} → ${s.code}',
            [
              s.typeLabel,
              s.mode,
              if (s.min != null) '${s.min}..${s.max}',
              if (s.scale != 0) 'scale ${s.scale}',
              if (s.unit != null && s.unit!.isNotEmpty) s.unit!,
              if (s.range.isNotEmpty) s.range.join('|'),
              '= ${_short(dev.dps[s.id])}',
            ].join(' · '),
          ),
      ]),
    ];
  }

  static String _short(Object? v) {
    final s = v?.toString() ?? '—';
    return s.length > 24 ? '${s.substring(0, 24)}…' : s;
  }

  @override
  Future<void> dispose() async {
    await _eventsSub?.cancel();
    await _controller.close();
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(currentDevices);
  }
}
