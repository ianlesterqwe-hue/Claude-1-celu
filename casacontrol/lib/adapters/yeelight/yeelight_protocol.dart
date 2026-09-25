/// Implementación pura (sin sockets ni Flutter) del
/// "Yeelight WiFi Light Inter-Operation Specification"
/// (Yeelight Third-party Control Protocol).
///
/// Resumen del protocolo:
///  * Descubrimiento SSDP-like: M-SEARCH a 239.255.255.250:1982 con
///    `ST: wifi_bulb`; la ampolleta responde por unicast con cabeceras HTTP.
///    También anuncia su presencia con NOTIFY periódicos al mismo grupo.
///  * Control: TCP a la IP de `Location` (puerto 55443), un JSON por línea
///    terminado en `\r\n`: `{"id":1,"method":"set_power","params":[...]}`.
///  * Respuestas: `{"id":1,"result":["ok"]}` o `{"id":1,"error":{...}}`.
///  * Notificaciones: `{"method":"props","params":{"power":"on",...}}`.
///  * Límites: 60 comandos/min por conexión, 144/min en total LAN,
///    máximo 4 conexiones TCP simultáneas por ampolleta.
///  * set_bright / set_rgb / set_hsv / set_ct_abx sólo se aceptan con la
///    ampolleta encendida.
library;

import 'dart:convert';

import '../../core/models/device.dart';

const yeelightMulticastAddress = '239.255.255.250';
const yeelightDiscoveryPort = 1982;
const yeelightDefaultControlPort = 55443;
const yeelightMaxCommandsPerMinute = 60;

/// Rango CT documentado para ampolletas color (la 1S incluida).
const yeelightMinKelvin = 1700;
const yeelightMaxKelvin = 6500;

/// Duración mínima de una transición "smooth" según la especificación.
const yeelightMinSmoothMs = 30;

const yeelightSearchMessage = 'M-SEARCH * HTTP/1.1\r\n'
    'HOST: 239.255.255.250:1982\r\n'
    'MAN: "ssdp:discover"\r\n'
    'ST: wifi_bulb\r\n'
    '\r\n';

/// Propiedades que se leen con get_prop.
const yeelightProps = [
  'power',
  'bright',
  'ct',
  'rgb',
  'hue',
  'sat',
  'color_mode',
  'flowing',
  'delayoff',
  'name',
  'music_on',
];

/// Datos de una respuesta de descubrimiento o de un NOTIFY.
class YeelightDiscoveryInfo {
  YeelightDiscoveryInfo({
    required this.id,
    required this.host,
    required this.port,
    required this.model,
    required this.firmwareVersion,
    required this.support,
    required this.props,
  });

  /// Id único de la ampolleta (p. ej. `0x000000000015243f`). Es la
  /// identidad estable: la IP puede cambiar.
  final String id;
  final String host;
  final int port;
  final String model;
  final String firmwareVersion;

  /// Métodos soportados, según la cabecera `support`.
  final Set<String> support;

  /// power, bright, color_mode, ct, rgb, hue, sat, name.
  final Map<String, String> props;

  String get name => props['name'] ?? '';

  /// Parsea el texto de una respuesta `HTTP/1.1 200 OK` o `NOTIFY * HTTP/1.1`.
  /// Devuelve null si no es un mensaje Yeelight válido.
  static YeelightDiscoveryInfo? parse(String message) {
    final lines = message.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) return null;
    final first = lines.first.trim().toUpperCase();
    if (!first.startsWith('HTTP/1.1 200') && !first.startsWith('NOTIFY')) {
      return null;
    }
    final headers = <String, String>{};
    for (final line in lines.skip(1)) {
      final i = line.indexOf(':');
      if (i <= 0) continue;
      headers[line.substring(0, i).trim().toLowerCase()] =
          line.substring(i + 1).trim();
    }
    final location = headers['location'];
    final id = headers['id'];
    if (location == null || id == null || id.isEmpty) return null;
    final uri = Uri.tryParse(location);
    if (uri == null || uri.scheme != 'yeelight' || uri.host.isEmpty) {
      return null;
    }
    const propKeys = [
      'power',
      'bright',
      'color_mode',
      'ct',
      'rgb',
      'hue',
      'sat',
      'name',
    ];
    return YeelightDiscoveryInfo(
      id: id,
      host: uri.host,
      port: uri.hasPort ? uri.port : yeelightDefaultControlPort,
      model: headers['model'] ?? '',
      firmwareVersion: headers['fw_ver'] ?? '',
      support: (headers['support'] ?? '')
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toSet(),
      props: {
        for (final k in propKeys)
          if (headers[k] != null) k: headers[k]!,
      },
    );
  }
}

/// Construye la línea JSON de un comando.
String encodeCommand(int id, String method, List<Object> params) =>
    '${jsonEncode({'id': id, 'method': method, 'params': params})}\r\n';

sealed class YeelightMessage {
  const YeelightMessage();

  /// Parsea una línea recibida por TCP. Devuelve null si no se reconoce.
  static YeelightMessage? parse(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final id = decoded['id'];
    if (decoded['method'] == 'props' && decoded['params'] is Map) {
      return YeelightNotification({
        for (final e in (decoded['params'] as Map).entries)
          e.key.toString(): e.value.toString(),
      });
    }
    if (id is int && decoded['error'] is Map) {
      final err = decoded['error'] as Map;
      return YeelightError(
        id,
        (err['code'] as num?)?.toInt() ?? -1,
        err['message']?.toString() ?? 'error',
      );
    }
    if (id is int && decoded['result'] is List) {
      return YeelightResult(
        id,
        [for (final r in decoded['result'] as List) r.toString()],
      );
    }
    return null;
  }
}

class YeelightResult extends YeelightMessage {
  const YeelightResult(this.id, this.result);
  final int id;
  final List<String> result;
}

class YeelightError extends YeelightMessage {
  const YeelightError(this.id, this.code, this.message);
  final int id;
  final int code;
  final String message;
}

class YeelightNotification extends YeelightMessage {
  const YeelightNotification(this.props);
  final Map<String, String> props;
}

/// Parámetros de efecto: `["smooth", ms]` o `["sudden", 0]`.
List<Object> effectParams(Duration? transition) {
  final ms = transition?.inMilliseconds ?? 0;
  if (ms <= 0) return ['sudden', 0];
  return ['smooth', ms < yeelightMinSmoothMs ? yeelightMinSmoothMs : ms];
}

/// Convierte propiedades Yeelight (de descubrimiento, get_prop o
/// notificación) a [DeviceState]. Las claves ausentes quedan en null.
DeviceState stateFromProps(Map<String, String> p) {
  final power = switch (p['power']) {
    'on' => true,
    'off' => false,
    _ => null,
  };
  final bright = int.tryParse(p['bright'] ?? '');
  final ct = int.tryParse(p['ct'] ?? '');
  final colorMode = int.tryParse(p['color_mode'] ?? '');

  HsvColor? color;
  final hue = int.tryParse(p['hue'] ?? '');
  final sat = int.tryParse(p['sat'] ?? '');
  final rgb = int.tryParse(p['rgb'] ?? '');
  if (colorMode == 1 && rgb != null) {
    color = rgbToHsv(rgb);
  } else if (colorMode == 3 && hue != null && sat != null) {
    color = HsvColor(hue, sat);
  } else if (colorMode == null && hue != null && sat != null) {
    // Notificación parcial (p. ej. sólo hue/sat tras set_hsv).
    color = HsvColor(hue, sat);
  } else if (colorMode == null && rgb != null) {
    color = rgbToHsv(rgb);
  }

  final mode = switch (colorMode) {
    1 || 3 => LightMode.color,
    2 => LightMode.white,
    null => p['flowing'] == '1' ? LightMode.scene : null,
    _ => LightMode.unknown,
  };

  return DeviceState(
    power: power,
    brightness: bright?.clamp(1, 100),
    colorTemperatureK: ct,
    color: color,
    mode: mode,
    countdownSeconds: switch (int.tryParse(p['delayoff'] ?? '')) {
      final m? => m * 60,
      null => null,
    },
  );
}

/// get_prop devuelve los valores en el mismo orden que se pidieron;
/// "" significa propiedad no soportada.
Map<String, String> zipProps(List<String> names, List<String> values) => {
      for (var i = 0; i < names.length && i < values.length; i++)
        if (values[i].isNotEmpty) names[i]: values[i],
    };

HsvColor rgbToHsv(int rgb) {
  final r = ((rgb >> 16) & 0xFF) / 255.0;
  final g = ((rgb >> 8) & 0xFF) / 255.0;
  final b = (rgb & 0xFF) / 255.0;
  final max = [r, g, b].reduce((a, b) => a > b ? a : b);
  final min = [r, g, b].reduce((a, b) => a < b ? a : b);
  final delta = max - min;
  double h;
  if (delta == 0) {
    h = 0;
  } else if (max == r) {
    h = 60 * (((g - b) / delta) % 6);
  } else if (max == g) {
    h = 60 * (((b - r) / delta) + 2);
  } else {
    h = 60 * (((r - g) / delta) + 4);
  }
  final s = max == 0 ? 0.0 : delta / max;
  return HsvColor(h.round() % 360, (s * 100).round());
}

int hsvToRgb(HsvColor c, {double value = 1.0}) {
  final h = (c.hue % 360) / 60.0;
  final s = c.saturation.clamp(0, 100) / 100.0;
  final v = value;
  final chroma = v * s;
  final x = chroma * (1 - ((h % 2) - 1).abs());
  final m = v - chroma;
  final (r, g, b) = switch (h.floor()) {
    0 => (chroma, x, 0.0),
    1 => (x, chroma, 0.0),
    2 => (0.0, chroma, x),
    3 => (0.0, x, chroma),
    4 => (x, 0.0, chroma),
    _ => (chroma, 0.0, x),
  };
  int ch(double c) => ((c + m) * 255).round().clamp(0, 255);
  return (ch(r) << 16) | (ch(g) << 8) | ch(b);
}
