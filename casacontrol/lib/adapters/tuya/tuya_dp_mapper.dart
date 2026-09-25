/// Traduce el esquema de Data Points (DP) que entrega el SDK de Tuya a
/// capacidades genéricas de CasaControl, y órdenes genéricas a DPs.
///
/// Regla del proyecto: NUNCA se asumen DP IDs. Se busca por el `code`
/// estándar de Tuya (switch_led, bright_value_v2, switch_1, cur_power, ...)
/// dentro del esquema real del dispositivo, y el DP ID se toma de ese
/// esquema. Si un código no existe, la capacidad no se ofrece.
library;

import 'dart:convert';
import 'dart:math' as math;

import '../../core/models/capability.dart';
import '../../core/models/command.dart';
import '../../core/models/device.dart';

enum DpType { boolean, value, enumeration, string, raw, bitmap, unknown }

class DpSchema {
  const DpSchema({
    required this.id,
    required this.code,
    required this.type,
    required this.mode,
    this.min,
    this.max,
    this.scale = 0,
    this.step,
    this.unit,
    this.range = const [],
  });

  final String id;
  final String code;
  final DpType type;

  /// rw, ro o wr.
  final String mode;
  final int? min;
  final int? max;
  final int scale;
  final int? step;
  final String? unit;
  final List<String> range;

  bool get writable => mode.contains('w');

  /// A partir del mapa que envía la capa nativa (SchemaBean serializado).
  factory DpSchema.fromMap(Map<Object?, Object?> m) {
    var property = <String, Object?>{};
    final rawProp = m['property'];
    if (rawProp is String && rawProp.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawProp);
        if (decoded is Map) property = decoded.cast<String, Object?>();
      } on FormatException {
        // Propiedad no JSON: se ignora.
      }
    } else if (rawProp is Map) {
      property = rawProp.cast<String, Object?>();
    }
    final typeStr =
        (m['schemaType'] ?? property['type'] ?? m['type'])?.toString() ?? '';
    return DpSchema(
      id: m['id'].toString(),
      code: m['code']?.toString() ?? '',
      type: switch (typeStr) {
        'bool' => DpType.boolean,
        'value' => DpType.value,
        'enum' => DpType.enumeration,
        'string' => DpType.string,
        'raw' => DpType.raw,
        'bitmap' => DpType.bitmap,
        _ => DpType.unknown,
      },
      mode: m['mode']?.toString() ?? 'rw',
      min: (property['min'] as num?)?.toInt(),
      max: (property['max'] as num?)?.toInt(),
      scale: (property['scale'] as num?)?.toInt() ?? 0,
      step: (property['step'] as num?)?.toInt(),
      unit: property['unit']?.toString(),
      range: [
        for (final r in (property['range'] as List?) ?? const []) r.toString()
      ],
    );
  }

  String get typeLabel => switch (type) {
        DpType.boolean => 'bool',
        DpType.value => 'value',
        DpType.enumeration => 'enum',
        DpType.string => 'string',
        DpType.raw => 'raw',
        DpType.bitmap => 'bitmap',
        DpType.unknown => '?',
      };
}

/// Rango nominal usado cuando Tuya sólo expone temperatura relativa.
const tuyaNominalWarmK = 2700;
const tuyaNominalColdK = 6500;

const _lightCategories = {'dj', 'dd', 'fwd', 'dc', 'xdd', 'fsd', 'tgq', 'tyndj'};
const _plugCategories = {'cz', 'pc', 'kg', 'tdq'};

/// Mapeo resuelto para un dispositivo concreto.
class TuyaDpMapping {
  TuyaDpMapping._(this.schema, this.category);

  factory TuyaDpMapping.fromSchema(List<DpSchema> schema, {String? category}) =>
      TuyaDpMapping._({for (final s in schema) s.code: s}, category);

  /// Por código.
  final Map<String, DpSchema> schema;
  final String? category;

  DpSchema? _first(List<String> codes, DpType type) {
    for (final c in codes) {
      final s = schema[c];
      if (s != null && s.type == type) return s;
    }
    return null;
  }

  late final DpSchema? power = _first(
      const ['switch_led', 'switch_1', 'switch', 'led_switch'],
      DpType.boolean);
  late final DpSchema? workMode = _first(const ['work_mode'], DpType.enumeration);
  late final DpSchema? brightness =
      _first(const ['bright_value_v2', 'bright_value'], DpType.value);
  late final DpSchema? temperature =
      _first(const ['temp_value_v2', 'temp_value'], DpType.value);
  late final DpSchema? colour = schema['colour_data_v2'] ?? schema['colour_data'];
  bool get _colourV2 => colour?.code == 'colour_data_v2';
  late final DpSchema? countdown =
      _first(const ['countdown_1', 'countdown'], DpType.value);
  late final DpSchema? scene = schema['scene_data_v2'] ?? schema['scene_data'];

  late final Map<EnergyMetric, DpSchema> energy = {
    for (final (metric, code) in const [
      (EnergyMetric.powerW, 'cur_power'),
      (EnergyMetric.currentMa, 'cur_current'),
      (EnergyMetric.voltageV, 'cur_voltage'),
      (EnergyMetric.energyKwh, 'add_ele'),
    ])
      if (schema[code]?.type == DpType.value) metric: schema[code]!,
  };

  DeviceKind get kind {
    if (_lightCategories.contains(category)) return DeviceKind.light;
    if (_plugCategories.contains(category)) return DeviceKind.plug;
    if (brightness != null || colour != null) return DeviceKind.light;
    if (power != null) return DeviceKind.plug;
    return DeviceKind.other;
  }

  List<Capability> get capabilities => [
        if (power?.writable ?? false) const PowerCapability(),
        if (brightness?.writable ?? false) const BrightnessCapability(),
        if (colour?.writable ?? false) const ColorCapability(),
        if (temperature?.writable ?? false)
          const ColorTemperatureCapability(
            minKelvin: tuyaNominalWarmK,
            maxKelvin: tuyaNominalColdK,
            approximate: true,
          ),
        if (countdown?.writable ?? false)
          CountdownCapability(maxSeconds: countdown!.max ?? 86400),
        if (energy.isNotEmpty) EnergyMeterCapability(energy.keys.toSet()),
        if (scene != null) const NativeScenesCapability(),
      ];

  /// Decodifica el mapa de DPs actual (`{dpId: valor}`).
  DeviceState decodeState(Map<String, Object?> dps) {
    Object? val(DpSchema? s) => s == null ? null : dps[s.id];

    final mode = switch (val(workMode)) {
      'white' => LightMode.white,
      'colour' => LightMode.color,
      'scene' || 'music' => LightMode.scene,
      null => null,
      _ => LightMode.unknown,
    };

    final colourValue = val(colour);
    final hsv = colourValue == null ? null : decodeColour(colourValue);

    int? brightnessPct;
    if (mode == LightMode.color && hsv != null) {
      brightnessPct = hsv.valuePercent;
    } else if (val(brightness) case final num b) {
      brightnessPct = _toPercent(b, brightness!);
    }

    int? kelvin;
    if (val(temperature) case final num t) {
      final s = temperature!;
      final frac = (t - (s.min ?? 0)) / ((s.max ?? 1000) - (s.min ?? 0));
      kelvin = (tuyaNominalWarmK +
              frac.clamp(0, 1) * (tuyaNominalColdK - tuyaNominalWarmK))
          .round();
    }

    return DeviceState(
      power: val(power) as bool?,
      brightness: brightnessPct,
      color: hsv?.color,
      colorTemperatureK: kelvin,
      mode: mode,
      countdownSeconds: (val(countdown) as num?)?.toInt(),
      energy: {
        for (final e in energy.entries)
          if (dps[e.value.id] case final num raw)
            e.key: raw / math.pow(10, e.value.scale),
      },
    );
  }

  /// Traduce una orden genérica a DPs `{dpId: valor}` listos para publicar.
  /// Lanza [UnsupportedError] si el dispositivo no expone el DP necesario.
  Map<String, Object> encode(DeviceCommand command, DeviceState current) {
    DpSchema need(DpSchema? s, String what) =>
        (s != null && s.writable) ? s : throw UnsupportedError(what);

    switch (command) {
      case SetPower(:final on):
        return {need(power, 'encender/apagar').id: on};
      case SetBrightness(:final percent):
        if (current.mode == LightMode.color && colour != null) {
          final c = current.color ?? const HsvColor(0, 100);
          return {
            colour!.id: encodeColour(c, percent),
            if (power != null && current.power != true) power!.id: true,
          };
        }
        final s = need(brightness, 'brillo');
        return {
          s.id: _fromPercent(percent, s),
          if (workMode != null && current.mode == LightMode.color)
            workMode!.id: 'white',
          if (power != null && current.power != true) power!.id: true,
        };
      case SetColor(:final color):
        final s = need(colour, 'color');
        return {
          if (workMode != null) workMode!.id: 'colour',
          s.id: encodeColour(color, current.brightness ?? 100),
          if (power != null && current.power != true) power!.id: true,
        };
      case SetColorTemperature(:final kelvin):
        final s = need(temperature, 'temperatura de color');
        final frac = (kelvin - tuyaNominalWarmK) /
            (tuyaNominalColdK - tuyaNominalWarmK);
        final lo = s.min ?? 0, hi = s.max ?? 1000;
        return {
          if (workMode != null) workMode!.id: 'white',
          s.id: _snap((lo + frac.clamp(0, 1) * (hi - lo)).round(), s),
          if (power != null && current.power != true) power!.id: true,
        };
      case SetCountdown(:final duration):
        final s = need(countdown, 'temporizador');
        return {s.id: _snap(duration.inSeconds, s)};
    }
  }

  ({HsvColor color, int valuePercent})? decodeColour(Object raw) {
    int sMax = _colourV2 ? 1000 : 255;
    int vMax = sMax;
    int? h, s, v;
    if (raw is Map) {
      h = (raw['h'] as num?)?.toInt();
      s = (raw['s'] as num?)?.toInt();
      v = (raw['v'] as num?)?.toInt();
    } else {
      final str = raw.toString();
      if (str.startsWith('{')) {
        try {
          return decodeColour(jsonDecode(str) as Map);
        } on FormatException {
          return null;
        }
      }
      if (str.length == 12) {
        // v2: HHHHSSSSVVVV (h 0-360, s/v 0-1000)
        h = int.tryParse(str.substring(0, 4), radix: 16);
        s = int.tryParse(str.substring(4, 8), radix: 16);
        v = int.tryParse(str.substring(8, 12), radix: 16);
        sMax = vMax = 1000;
      } else if (str.length == 14) {
        // v1: RRGGBBHHHHSSVV (h 0-360, s/v 0-255)
        h = int.tryParse(str.substring(6, 10), radix: 16);
        s = int.tryParse(str.substring(10, 12), radix: 16);
        v = int.tryParse(str.substring(12, 14), radix: 16);
        sMax = vMax = 255;
      }
    }
    if (h == null || s == null || v == null) return null;
    return (
      color: HsvColor(h % 360, (s * 100 / sMax).round().clamp(0, 100)),
      valuePercent: (v * 100 / vMax).round().clamp(1, 100),
    );
  }

  String encodeColour(HsvColor c, int valuePercent) {
    final h = c.hue % 360;
    if (_colourV2) {
      final s = (c.saturation.clamp(0, 100) * 10);
      final v = (valuePercent.clamp(1, 100) * 10);
      return [h, s, v].map((x) => x.toRadixString(16).padLeft(4, '0')).join();
    }
    final s = (c.saturation.clamp(0, 100) * 255 / 100).round();
    final v = (valuePercent.clamp(1, 100) * 255 / 100).round();
    final rgb = _hsvToRgb(h, s / 255, v / 255);
    return rgb.toRadixString(16).padLeft(6, '0') +
        h.toRadixString(16).padLeft(4, '0') +
        s.toRadixString(16).padLeft(2, '0') +
        v.toRadixString(16).padLeft(2, '0');
  }

  static int _toPercent(num raw, DpSchema s) {
    final lo = s.min ?? 0, hi = s.max ?? 1000;
    if (hi <= lo) return 100;
    return (((raw - lo) / (hi - lo)) * 99 + 1).round().clamp(1, 100);
  }

  static int _fromPercent(int percent, DpSchema s) {
    final lo = s.min ?? 0, hi = s.max ?? 1000;
    return _snap((lo + (percent - 1) / 99 * (hi - lo)).round(), s);
  }

  static int _snap(int v, DpSchema s) {
    final lo = s.min ?? v, hi = s.max ?? v;
    var r = v.clamp(lo, hi);
    final step = s.step;
    if (step != null && step > 1) r = lo + ((r - lo) ~/ step) * step;
    return r;
  }

  static int _hsvToRgb(int hue, double s, double v) {
    final c = v * s;
    final hp = hue / 60.0;
    final x = c * (1 - ((hp % 2) - 1).abs());
    final (r, g, b) = switch (hp.floor()) {
      0 => (c, x, 0.0),
      1 => (x, c, 0.0),
      2 => (0.0, c, x),
      3 => (0.0, x, c),
      4 => (x, 0.0, c),
      _ => (c, 0.0, x),
    };
    final m = v - c;
    int ch(double y) => ((y + m) * 255).round().clamp(0, 255);
    return (ch(r) << 16) | (ch(g) << 8) | ch(b);
  }
}
