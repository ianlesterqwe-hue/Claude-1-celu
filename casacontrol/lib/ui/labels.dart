import 'package:flutter/material.dart';

import '../core/models/capability.dart';
import '../core/models/device.dart';
import '../adapters/yeelight/yeelight_protocol.dart' show hsvToRgb;

String whiteLabel(int kelvin) {
  if (kelvin < 3500) return 'Blanco cálido';
  if (kelvin < 5000) return 'Blanco neutro';
  return 'Blanco frío';
}

String hueLabel(HsvColor c) {
  if (c.saturation < 15) return 'Blanco';
  final h = c.hue;
  if (h < 15 || h >= 345) return 'Rojo';
  if (h < 45) return 'Naranja';
  if (h < 70) return 'Amarillo';
  if (h < 160) return 'Verde';
  if (h < 200) return 'Cian';
  if (h < 255) return 'Azul';
  if (h < 290) return 'Violeta';
  return 'Rosa';
}

Color colorFromHsv(HsvColor c) => Color(0xFF000000 | hsvToRgb(c));

IconData deviceIcon(Device d) => switch (d.kind) {
      DeviceKind.plug => Icons.power,
      DeviceKind.light when d.capabilities.has<ColorCapability>() =>
        Icons.color_lens_outlined,
      DeviceKind.light => Icons.lightbulb_outline,
      DeviceKind.other => Icons.devices_other,
    };

/// Líneas de estado para la tarjeta: "Encendida", "Brillo 70%", "Azul".
List<String> stateLines(Device d) {
  final s = d.state;
  final isLight = d.kind == DeviceKind.light;
  final lines = <String>[
    switch (s.power) {
      true => isLight ? 'Encendida' : 'Encendido',
      false => isLight ? 'Apagada' : 'Apagado',
      null => 'Estado desconocido',
    },
  ];
  if (s.power == true && isLight) {
    if (s.mode == LightMode.color && s.color != null) {
      lines.add(hueLabel(s.color!));
    } else if (s.mode == LightMode.scene) {
      lines.add('Escena');
    } else if (s.colorTemperatureK != null) {
      lines.add(whiteLabel(s.colorTemperatureK!));
    }
    if (s.brightness != null) lines.add('Brillo ${s.brightness}%');
  }
  final meter = d.capabilities.get<EnergyMeterCapability>();
  final watts = s.energy[EnergyMetric.powerW];
  if (meter != null && watts != null) {
    lines.add('${watts.toStringAsFixed(1)} W');
  }
  return lines;
}
