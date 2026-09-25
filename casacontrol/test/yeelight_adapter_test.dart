import 'dart:io';

import 'package:casacontrol/adapters/yeelight/yeelight_adapter.dart';
import 'package:casacontrol/adapters/yeelight/yeelight_connection.dart';
import 'package:casacontrol/adapters/yeelight/yeelight_discovery.dart';
import 'package:casacontrol/core/models/capability.dart';
import 'package:casacontrol/core/models/command.dart';
import 'package:casacontrol/core/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_yeelight.dart';

void main() {
  late FakeYeelight bulb;
  late YeelightAdapter adapter;

  Future<Device> waitFor(bool Function(Device d) predicate) async {
    final current = adapter.currentDevices.where(predicate);
    if (current.isNotEmpty) return current.first;
    return adapter.devices
        .map((l) => l.where(predicate))
        .firstWhere((l) => l.isNotEmpty)
        .then((l) => l.first)
        .timeout(const Duration(seconds: 5));
  }

  setUp(() async {
    bulb = await FakeYeelight.start();
    adapter = YeelightAdapter(
      discovery: YeelightDiscovery(
        target: InternetAddress.loopbackIPv4,
        port: bulb.udpPort,
        listenForAdvertisements: false,
      ),
      searchTimeout: const Duration(milliseconds: 300),
      searchInterval: const Duration(hours: 1),
    );
  });

  tearDown(() async {
    await adapter.dispose();
    await bulb.close();
  });

  test('descubre la ampolleta sin IP fija y expone sus capacidades', () async {
    await adapter.start();
    final d = await waitFor((d) => d.online);
    expect(d.id, 'yeelight:0x0000000012345678');
    expect(d.name, 'Salon');
    expect(d.connectivity, Connectivity.lan);
    expect(d.capabilities.has<PowerCapability>(), isTrue);
    expect(d.capabilities.has<BrightnessCapability>(), isTrue);
    expect(d.capabilities.has<ColorCapability>(), isTrue);
    expect(d.capabilities.get<ColorTemperatureCapability>()!.minKelvin, 1700);
    expect(d.state.power, isFalse);
  });

  test('ON, OFF, brillo, color y temperatura por LAN', () async {
    await adapter.start();
    final d = await waitFor((d) => d.online);

    await adapter.execute(d.id, const SetPower(true));
    expect(bulb.props['power'], 'on');

    await adapter.execute(d.id, const SetBrightness(35));
    expect(bulb.props['bright'], '35');

    await adapter.execute(d.id, const SetColor(HsvColor(230, 90)));
    expect(bulb.props['hue'], '230');
    expect(bulb.props['sat'], '90');
    expect(bulb.props['color_mode'], '3');

    await adapter.execute(d.id,
        const SetColorTemperature(2700, transition: Duration(milliseconds: 400)));
    expect(bulb.props['ct'], '2700');
    expect(bulb.commands.last['params'], [2700, 'smooth', 400]);

    await adapter.execute(d.id, const SetPower(false));
    expect(bulb.props['power'], 'off');

    final after = await waitFor((x) =>
        x.state.power == false && x.state.colorTemperatureK == 2700);
    expect(after.state.mode, LightMode.white);
  });

  test('enciende primero si se cambia el color con la luz apagada', () async {
    await adapter.start();
    final d = await waitFor((d) => d.online);
    await adapter.execute(d.id, const SetColorTemperature(3000));
    final methods = bulb.commands.map((c) => c['method']).toList();
    expect(methods.sublist(methods.length - 2), ['set_power', 'set_ct_abx']);
    expect(bulb.props['ct'], '3000');
  });

  test('reconecta cuando cambia la dirección de la ampolleta', () async {
    await adapter.start();
    final d = await waitFor((d) => d.online);
    await adapter.execute(d.id, const SetPower(true));
    await bulb.moveTcp();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // El siguiente comando debe redescubrir y usar el puerto nuevo.
    await adapter.execute(d.id, const SetBrightness(80));
    expect(bulb.props['bright'], '80');
  });

  test('diagnóstico no expone el id completo', () async {
    await adapter.start();
    final d = await waitFor((d) => d.online);
    await adapter.testConnection(d.id);
    final sections = await adapter.diagnostics(d.id);
    final entries = {for (final e in sections.first.entries) e.label: e.value};
    expect(entries['ID'], '0x00…5678');
    expect(entries['Control LAN disponible'], 'Sí');
    expect(entries['Firmware'], '38');
  });

  test('RateLimiter espera cuando se supera el límite', () async {
    final limiter =
        RateLimiter(2, window: const Duration(milliseconds: 200));
    final sw = Stopwatch()..start();
    await limiter.acquire();
    await limiter.acquire();
    await limiter.acquire();
    expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(150));
  });
}
