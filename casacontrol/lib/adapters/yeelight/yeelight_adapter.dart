import 'dart:async';

import '../../core/adapters/device_adapter.dart';
import '../../core/models/capability.dart';
import '../../core/models/command.dart';
import '../../core/models/device.dart';
import '../../core/models/diagnostics.dart';
import 'yeelight_connection.dart';
import 'yeelight_discovery.dart';
import 'yeelight_protocol.dart';

typedef YeelightConnector = Future<YeelightConnection> Function(
    String host, int port);

/// Control LAN directo de ampolletas Yeelight (sin nube).
///
/// Identidad = `id` Yeelight; la IP se toma siempre del último
/// descubrimiento, así que un cambio de IP por DHCP se resuelve solo.
class YeelightAdapter implements DeviceAdapter {
  YeelightAdapter({
    YeelightDiscovery? discovery,
    YeelightConnector? connector,
    this.searchInterval = const Duration(seconds: 60),
    this.searchTimeout = const Duration(seconds: 3),
  })  : _discovery = discovery ?? YeelightDiscovery(),
        _connector = connector ?? YeelightConnection.connect;

  final YeelightDiscovery _discovery;
  final YeelightConnector _connector;
  final Duration searchInterval;
  final Duration searchTimeout;

  final _controller = StreamController<List<Device>>.broadcast();
  final _entries = <String, _Bulb>{};
  StreamSubscription<YeelightDiscoveryInfo>? _foundSub;
  Timer? _periodic;
  bool _disposed = false;

  @override
  String get id => 'yeelight';

  @override
  String get displayName => 'Yeelight (LAN)';

  @override
  Stream<List<Device>> get devices => _controller.stream;

  @override
  List<Device> get currentDevices =>
      [for (final e in _entries.values) e.toDevice()];

  @override
  Future<void> start() async {
    _foundSub = _discovery.found.listen(_onFound);
    await _discovery.startListening();
    await refresh();
    _periodic = Timer.periodic(searchInterval, (_) => refresh());
  }

  /// Búsqueda activa. Las ampolletas nuevas o que cambiaron de IP se
  /// actualizan en [_onFound]; las que no responden quedan offline.
  @override
  Future<void> refresh() async {
    final found = await _discovery.search(timeout: searchTimeout);
    final ids = found.map((f) => f.id).toSet();
    for (final e in _entries.values) {
      if (!ids.contains(e.info.id) && !(e.connection?.isClosed == false)) {
        e.online = false;
      }
    }
    _emit();
    await Future.wait(
        _entries.values.where((e) => e.online).map(_ensureConnected));
  }

  void _onFound(YeelightDiscoveryInfo info) {
    final existing = _entries[info.id];
    if (existing == null) {
      _entries[info.id] = _Bulb(info)
        ..state = stateFromProps(info.props)
        ..online = true;
    } else {
      final moved =
          existing.info.host != info.host || existing.info.port != info.port;
      existing.info = info;
      existing.online = true;
      existing.state = existing.state.merge(stateFromProps(info.props));
      if (moved) {
        // Cambió la IP: la conexión vieja ya no sirve.
        existing.connection?.close();
        existing.connection = null;
      }
    }
    _emit();
  }

  Future<YeelightConnection> _ensureConnected(_Bulb bulb) {
    final c = bulb.connection;
    if (c != null && !c.isClosed) return Future.value(c);
    return bulb.connecting ??= _connect(bulb).whenComplete(() {
      bulb.connecting = null;
    });
  }

  Future<YeelightConnection> _connect(_Bulb bulb) async {
    YeelightConnection conn;
    try {
      conn = await _connector(bulb.info.host, bulb.info.port);
    } catch (e) {
      bulb.lastError = e.toString();
      bulb.lanControl = false;
      // Puede haber cambiado de IP: redescubrir y reintentar una vez.
      await _discovery.search(timeout: searchTimeout);
      try {
        conn = await _connector(bulb.info.host, bulb.info.port);
      } catch (e2) {
        bulb.online = false;
        bulb.lastError = e2.toString();
        _emit();
        rethrow;
      }
    }
    bulb
      ..connection = conn
      ..lanControl = true
      ..lastError = null
      ..online = true;
    conn.notifications.listen((props) {
      bulb.state = bulb.state.merge(stateFromProps(props));
      if (props['name'] case final n?) bulb.info.props['name'] = n;
      _emit();
    });
    unawaited(conn.done.then((_) => _onDisconnected(bulb, conn)));
    try {
      final props = await conn.getProps(yeelightProps);
      bulb.state = bulb.state.merge(stateFromProps(props));
      if (props['name'] case final n?) bulb.info.props['name'] = n;
    } on YeelightException catch (e) {
      bulb.lastError = e.toString();
    }
    _emit();
    return conn;
  }

  void _onDisconnected(_Bulb bulb, YeelightConnection conn) {
    if (_disposed || !identical(bulb.connection, conn)) return;
    bulb.connection = null;
    _emit();
    // Reconexión con espera creciente: 2, 5, 15, 30, 60 s.
    const delays = [2, 5, 15, 30, 60];
    Future<void> attempt(int i) async {
      if (_disposed || bulb.connection != null) return;
      await Future<void>.delayed(Duration(seconds: delays[i]));
      if (_disposed || bulb.connection != null) return;
      try {
        await _ensureConnected(bulb);
      } catch (_) {
        if (i + 1 < delays.length) await attempt(i + 1);
      }
    }

    unawaited(attempt(0));
  }

  _Bulb _bulb(String deviceId) {
    final bulb = _entries[deviceId.substring(id.length + 1)];
    if (bulb == null) {
      throw DeviceCommandException('Ampolleta no encontrada en la red');
    }
    return bulb;
  }

  @override
  Future<void> execute(String deviceId, DeviceCommand command) async {
    final bulb = _bulb(deviceId);
    try {
      final conn = await _ensureConnected(bulb);
      final fx = effectParams(command.transition);

      Future<void> ensureOn() async {
        if (bulb.state.power != true) {
          await conn.send('set_power', ['on', ...fx]);
          bulb.state = bulb.state.copyWith(power: true);
        }
      }

      switch (command) {
        case SetPower(:final on):
          await conn.send('set_power', [on ? 'on' : 'off', ...fx]);
          bulb.state = bulb.state.copyWith(power: on);
        case SetBrightness(:final percent):
          await ensureOn();
          await conn.send('set_bright', [percent.clamp(1, 100), ...fx]);
          bulb.state = bulb.state.copyWith(brightness: percent);
        case SetColor(:final color):
          await ensureOn();
          if (bulb.info.support.contains('set_hsv')) {
            await conn.send('set_hsv',
                [color.hue % 360, color.saturation.clamp(0, 100), ...fx]);
          } else {
            await conn.send('set_rgb', [hsvToRgb(color), ...fx]);
          }
          bulb.state =
              bulb.state.copyWith(color: color, mode: LightMode.color);
        case SetColorTemperature(:final kelvin):
          await ensureOn();
          final k = kelvin.clamp(yeelightMinKelvin, yeelightMaxKelvin);
          await conn.send('set_ct_abx', [k, ...fx]);
          bulb.state =
              bulb.state.copyWith(colorTemperatureK: k, mode: LightMode.white);
        case SetCountdown(:final duration):
          if (duration == Duration.zero) {
            await conn.send('cron_del', [0]);
            bulb.state = bulb.state.copyWith(countdownSeconds: 0);
          } else {
            final minutes = (duration.inSeconds / 60).ceil();
            await conn.send('cron_add', [0, minutes]);
            bulb.state = bulb.state.copyWith(countdownSeconds: minutes * 60);
          }
      }
      _emit();
    } on YeelightException catch (e) {
      throw DeviceCommandException(e.message, cause: e);
    }
  }

  /// Prueba de conexión para la pantalla de diagnóstico: abre (o reutiliza)
  /// la conexión y lee propiedades. Devuelve las propiedades leídas.
  Future<Map<String, String>> testConnection(String deviceId) async {
    final bulb = _bulb(deviceId);
    try {
      final conn = await _ensureConnected(bulb);
      final props = await conn.getProps(yeelightProps);
      bulb.state = bulb.state.merge(stateFromProps(props));
      _emit();
      return props;
    } on YeelightException catch (e) {
      throw DeviceCommandException(e.message, cause: e);
    }
  }

  @override
  Future<List<DiagnosticsSection>> diagnostics(String deviceId) async {
    final bulb = _bulb(deviceId);
    final s = bulb.state;
    final colorMode = switch (s.mode) {
      LightMode.white => 'Temperatura de color',
      LightMode.color => 'Color',
      LightMode.scene => 'Flujo / escena',
      _ => '—',
    };
    return [
      DiagnosticsSection('Yeelight LAN', [
        DiagnosticsEntry('Nombre', bulb.displayName),
        DiagnosticsEntry('Modelo', bulb.info.model),
        DiagnosticsEntry('ID', redactId(bulb.info.id)),
        DiagnosticsEntry('IP', '${bulb.info.host}:${bulb.info.port}'),
        DiagnosticsEntry('Firmware', bulb.info.firmwareVersion),
        DiagnosticsEntry('Encendida', switch (s.power) {
          true => 'Sí',
          false => 'No',
          null => '—',
        }),
        DiagnosticsEntry('Brillo', s.brightness == null ? '—' : '${s.brightness}%'),
        DiagnosticsEntry('Modo de color', colorMode),
        DiagnosticsEntry('Temperatura de color',
            s.colorTemperatureK == null ? '—' : '${s.colorTemperatureK} K'),
        DiagnosticsEntry('Control LAN disponible', switch (bulb.lanControl) {
          true => 'Sí',
          false => 'No (activar "Control LAN" en la app Yeelight)',
          null => 'Sin probar',
        }),
        if (bulb.lastError != null)
          DiagnosticsEntry('Último error', bulb.lastError!),
      ]),
      DiagnosticsSection('Métodos soportados', [
        DiagnosticsEntry('support', (bulb.info.support.toList()..sort()).join(' ')),
      ]),
    ];
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _periodic?.cancel();
    await _foundSub?.cancel();
    for (final e in _entries.values) {
      await e.connection?.close();
    }
    await _discovery.dispose();
    await _controller.close();
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(currentDevices);
  }
}

class _Bulb {
  _Bulb(this.info);

  YeelightDiscoveryInfo info;
  DeviceState state = const DeviceState();
  bool online = false;
  YeelightConnection? connection;
  Future<YeelightConnection>? connecting;

  /// null = no probado todavía.
  bool? lanControl;
  String? lastError;

  String get displayName => info.name.isNotEmpty
      ? info.name
      : 'Yeelight ${info.model.isEmpty ? '' : info.model}'.trim();

  List<Capability> get capabilities {
    final s = info.support;
    return [
      if (s.contains('set_power')) const PowerCapability(),
      if (s.contains('set_bright')) const BrightnessCapability(),
      if (s.contains('set_rgb') || s.contains('set_hsv'))
        const ColorCapability(),
      if (s.contains('set_ct_abx'))
        const ColorTemperatureCapability(
            minKelvin: yeelightMinKelvin, maxKelvin: yeelightMaxKelvin),
      if (s.contains('set_bright') || s.contains('set_ct_abx'))
        const TransitionCapability(),
      if (s.contains('cron_add')) const CountdownCapability(),
    ];
  }

  Device toDevice() => Device(
        id: 'yeelight:${info.id}',
        adapterId: 'yeelight',
        name: displayName,
        model: info.model,
        kind: DeviceKind.light,
        capabilities: capabilities,
        state: state,
        online: online,
        connectivity: Connectivity.lan,
      );
}
