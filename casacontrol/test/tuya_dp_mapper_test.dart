import 'package:casacontrol/adapters/tuya/tuya_dp_mapper.dart';
import 'package:casacontrol/core/models/capability.dart';
import 'package:casacontrol/core/models/command.dart';
import 'package:casacontrol/core/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los DP IDs de estos esquemas son INVENTADOS a propósito (101, 102...)
/// para comprobar que el mapeo se hace por código y nunca por número.
DpSchema dp(String id, String code, String type,
        {String mode = 'rw', String property = '{}'}) =>
    DpSchema.fromMap({
      'id': id,
      'code': code,
      'schemaType': type,
      'mode': mode,
      'property': property,
    });

void main() {
  group('luz RGBCW (v2)', () {
    final m = TuyaDpMapping.fromSchema([
      dp('101', 'switch_led', 'bool'),
      dp('102', 'work_mode', 'enum',
          property: '{"type":"enum","range":["white","colour","scene","music"]}'),
      dp('103', 'bright_value_v2', 'value',
          property: '{"type":"value","min":10,"max":1000,"scale":0,"step":1}'),
      dp('104', 'temp_value_v2', 'value',
          property: '{"type":"value","min":0,"max":1000,"scale":0,"step":1}'),
      dp('105', 'colour_data_v2', 'string'),
      dp('106', 'scene_data_v2', 'string'),
    ], category: 'dj');

    test('capacidades desde códigos reales', () {
      expect(m.kind, DeviceKind.light);
      final caps = m.capabilities;
      expect(caps.has<PowerCapability>(), isTrue);
      expect(caps.has<BrightnessCapability>(), isTrue);
      expect(caps.has<ColorCapability>(), isTrue);
      expect(caps.get<ColorTemperatureCapability>()!.approximate, isTrue);
      expect(caps.has<EnergyMeterCapability>(), isFalse);
      expect(caps.has<NativeScenesCapability>(), isTrue);
    });

    test('decodifica color v2 (HHHHSSSSVVVV)', () {
      // h=230 (0x00e6), s=1000 (0x03e8), v=350 (0x015e)
      final s = m.decodeState({
        '101': true,
        '102': 'colour',
        '105': '00e603e8015e',
      });
      expect(s.power, isTrue);
      expect(s.mode, LightMode.color);
      expect(s.color, const HsvColor(230, 100));
      expect(s.brightness, 35);
    });

    test('codifica color con work_mode y el DP id del esquema', () {
      final dps = m.encode(const SetColor(HsvColor(230, 100)),
          const DeviceState(power: true, brightness: 35));
      expect(dps, {'102': 'colour', '105': '00e603e8015e'});
    });

    test('brillo en modo blanco usa bright_value_v2 con min/max', () {
      final dps = m.encode(const SetBrightness(100),
          const DeviceState(power: true, mode: LightMode.white));
      expect(dps, {'103': 1000});
      final low = m.encode(const SetBrightness(1),
          const DeviceState(power: true, mode: LightMode.white));
      expect(low, {'103': 10});
    });

    test('brillo en modo color reescribe la V del color', () {
      final dps = m.encode(
          const SetBrightness(50),
          const DeviceState(
              power: true, mode: LightMode.color, color: HsvColor(0, 100)));
      expect(dps, {'105': '000003e801f4'});
    });

    test('temperatura: cálido = min, frío = max; enciende si está apagada', () {
      final dps = m.encode(
          const SetColorTemperature(6500), const DeviceState(power: false));
      expect(dps, {'102': 'white', '104': 1000, '101': true});
      final warm = m.decodeState({'104': 0});
      expect(warm.colorTemperatureK, tuyaNominalWarmK);
    });
  });

  group('enchufe Wi-Fi', () {
    test('con medición: sólo las métricas expuestas, con su escala', () {
      final m = TuyaDpMapping.fromSchema([
        dp('1', 'switch_1', 'bool'),
        dp('9', 'countdown_1', 'value',
            property: '{"min":0,"max":86400,"scale":0,"step":1,"unit":"s"}'),
        dp('19', 'cur_power', 'value',
            mode: 'ro', property: '{"min":0,"max":50000,"scale":1,"unit":"W"}'),
        dp('20', 'cur_voltage', 'value',
            mode: 'ro', property: '{"min":0,"max":5000,"scale":1,"unit":"V"}'),
      ], category: 'cz');
      expect(m.kind, DeviceKind.plug);
      final meter = m.capabilities.get<EnergyMeterCapability>()!;
      expect(meter.metrics, {EnergyMetric.powerW, EnergyMetric.voltageV});
      final s = m.decodeState({'1': true, '19': 125, '20': 2201});
      expect(s.power, isTrue);
      expect(s.energy[EnergyMetric.powerW], 12.5);
      expect(s.energy[EnergyMetric.voltageV], 220.1);
      expect(m.encode(const SetPower(false), s), {'1': false});
      expect(m.encode(const SetCountdown(Duration(minutes: 30)), s),
          {'9': 1800});
    });

    test('sin DPs de medición no hay EnergyMeterCapability', () {
      final m = TuyaDpMapping.fromSchema([dp('1', 'switch_1', 'bool')],
          category: 'cz');
      expect(m.capabilities.has<EnergyMeterCapability>(), isFalse);
      expect(
          () => m.encode(const SetBrightness(50), const DeviceState()),
          throwsUnsupportedError);
    });
  });

  test('color v1 (RRGGBBHHHHSSVV)', () {
    final m = TuyaDpMapping.fromSchema([dp('5', 'colour_data', 'string')]);
    final encoded = m.encodeColour(const HsvColor(120, 100), 100);
    expect(encoded, '00ff000078ffff');
    final decoded = m.decodeColour(encoded)!;
    expect(decoded.color, const HsvColor(120, 100));
    expect(decoded.valuePercent, 100);
  });
}
