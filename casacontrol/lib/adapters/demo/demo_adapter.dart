import 'dart:async';

import '../../core/adapters/device_adapter.dart';
import '../../core/models/capability.dart';
import '../../core/models/command.dart';
import '../../core/models/device.dart';
import '../../core/models/diagnostics.dart';

/// Demo Mode: simula los tres dispositivos reales del proyecto sin red.
/// Sirve para desarrollar la UI y para probar la app en cualquier teléfono.
class DemoAdapter implements DeviceAdapter {
  DemoAdapter({this.latency = const Duration(milliseconds: 150)});

  final Duration latency;
  final _controller = StreamController<List<Device>>.broadcast();
  final Map<String, Device> _devices = {};

  @override
  String get id => 'demo';

  @override
  String get displayName => 'Demo';

  @override
  Stream<List<Device>> get devices => _controller.stream;

  @override
  List<Device> get currentDevices => _devices.values.toList();

  @override
  Future<void> start() async {
    for (final d in _initial()) {
      _devices[d.id] = d;
    }
    _emit();
  }

  @override
  Future<void> refresh() async => _emit();

  @override
  Future<void> execute(String deviceId, DeviceCommand command) async {
    final device = _devices[deviceId];
    if (device == null) {
      throw DeviceCommandException('Dispositivo desconocido');
    }
    await Future<void>.delayed(latency);
    final s = device.state;
    final next = switch (command) {
      SetPower(:final on) => s.copyWith(power: on),
      SetBrightness(:final percent) =>
        s.copyWith(brightness: percent, power: true),
      SetColor(:final color) =>
        s.copyWith(color: color, mode: LightMode.color, power: true),
      SetColorTemperature(:final kelvin) => s.copyWith(
          colorTemperatureK: kelvin, mode: LightMode.white, power: true),
      SetCountdown(:final duration) =>
        s.copyWith(countdownSeconds: duration.inSeconds),
    };
    _devices[deviceId] = device.copyWith(state: next);
    _emit();
  }

  @override
  Future<List<DiagnosticsSection>> diagnostics(String deviceId) async => [
        DiagnosticsSection('Demo', [
          DiagnosticsEntry('Dispositivo', _devices[deviceId]?.name ?? '—'),
          const DiagnosticsEntry('Origen', 'Simulado (Demo Mode)'),
        ]),
      ];

  @override
  Future<void> dispose() => _controller.close();

  void _emit() {
    if (!_controller.isClosed) _controller.add(currentDevices);
  }

  static List<Device> _initial() => const [
        Device(
          id: 'demo:yeelight-1s',
          adapterId: 'demo',
          name: 'Yeelight 1S',
          room: 'Salón',
          model: 'Yeelight LED Bulb 1S (demo)',
          kind: DeviceKind.light,
          online: true,
          connectivity: Connectivity.lan,
          capabilities: [
            PowerCapability(),
            BrightnessCapability(),
            ColorCapability(),
            ColorTemperatureCapability(minKelvin: 1700, maxKelvin: 6500),
            TransitionCapability(),
          ],
          state: DeviceState(
            power: true,
            brightness: 70,
            colorTemperatureK: 2700,
            mode: LightMode.white,
          ),
        ),
        Device(
          id: 'demo:beacon-rgbcw-2',
          adapterId: 'demo',
          name: 'Beacon RGBCW 2',
          room: 'Salón',
          model: 'Tuya Beacon RGBCW (demo)',
          kind: DeviceKind.light,
          online: true,
          connectivity: Connectivity.bluetooth,
          capabilities: [
            PowerCapability(),
            BrightnessCapability(),
            ColorCapability(),
            ColorTemperatureCapability(
                minKelvin: 2700, maxKelvin: 6500, approximate: true),
          ],
          state: DeviceState(
            power: true,
            brightness: 35,
            color: HsvColor(230, 100),
            mode: LightMode.color,
          ),
        ),
        Device(
          id: 'demo:wifi-plug-3',
          adapterId: 'demo',
          name: 'WiFi Plug 3',
          room: 'Salón',
          model: 'Tuya WiFi Plug (demo)',
          kind: DeviceKind.plug,
          online: true,
          connectivity: Connectivity.tuyaCloudLan,
          capabilities: [
            PowerCapability(),
            CountdownCapability(),
            ScheduleCapability(),
          ],
          state: DeviceState(power: true, countdownSeconds: 0),
        ),
      ];
}
