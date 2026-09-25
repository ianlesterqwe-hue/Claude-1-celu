import 'device.dart';

/// Órdenes genéricas que la UI envía a un [DeviceAdapter].
sealed class DeviceCommand {
  const DeviceCommand({this.transition});

  /// Duración de la transición, si el dispositivo la soporta.
  final Duration? transition;
}

class SetPower extends DeviceCommand {
  const SetPower(this.on, {super.transition});
  final bool on;
}

class SetBrightness extends DeviceCommand {
  const SetBrightness(this.percent, {super.transition})
      : assert(percent >= 1 && percent <= 100);
  final int percent;
}

class SetColor extends DeviceCommand {
  const SetColor(this.color, {super.transition});
  final HsvColor color;
}

class SetColorTemperature extends DeviceCommand {
  const SetColorTemperature(this.kelvin, {super.transition});
  final int kelvin;
}

/// Apaga (o cambia) el dispositivo tras [duration]. Duration.zero cancela.
class SetCountdown extends DeviceCommand {
  const SetCountdown(this.duration);
  final Duration duration;
}
