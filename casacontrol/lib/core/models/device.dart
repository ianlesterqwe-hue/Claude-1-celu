import 'capability.dart';

enum DeviceKind { light, plug, other }

/// Cómo se está controlando el dispositivo en este momento.
/// Se muestra en la tarjeta del dispositivo ("LAN", "Bluetooth", ...).
enum Connectivity {
  lan('LAN'),
  bluetooth('Bluetooth'),
  tuyaCloud('Tuya Cloud'),
  tuyaCloudLan('Tuya Cloud / LAN'),
  demo('Demo'),
  unknown('Desconocido');

  const Connectivity(this.label);
  final String label;
}

/// Color en HSV. hue 0..359, saturation 0..100.
class HsvColor {
  const HsvColor(this.hue, this.saturation);
  final int hue;
  final int saturation;

  @override
  bool operator ==(Object other) =>
      other is HsvColor && other.hue == hue && other.saturation == saturation;

  @override
  int get hashCode => Object.hash(hue, saturation);

  @override
  String toString() => 'HsvColor($hue, $saturation)';
}

enum LightMode { white, color, scene, unknown }

/// Estado genérico. Los campos son null cuando el dispositivo no los informa.
class DeviceState {
  const DeviceState({
    this.power,
    this.brightness,
    this.color,
    this.colorTemperatureK,
    this.mode,
    this.countdownSeconds,
    this.energy = const {},
  });

  final bool? power;

  /// 1..100
  final int? brightness;
  final HsvColor? color;
  final int? colorTemperatureK;
  final LightMode? mode;
  final int? countdownSeconds;
  final Map<EnergyMetric, double> energy;

  DeviceState copyWith({
    bool? power,
    int? brightness,
    HsvColor? color,
    int? colorTemperatureK,
    LightMode? mode,
    int? countdownSeconds,
    Map<EnergyMetric, double>? energy,
  }) {
    return DeviceState(
      power: power ?? this.power,
      brightness: brightness ?? this.brightness,
      color: color ?? this.color,
      colorTemperatureK: colorTemperatureK ?? this.colorTemperatureK,
      mode: mode ?? this.mode,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      energy: energy ?? this.energy,
    );
  }

  /// Combina: los campos no nulos de [other] pisan a los de este estado.
  DeviceState merge(DeviceState other) => copyWith(
        power: other.power,
        brightness: other.brightness,
        color: other.color,
        colorTemperatureK: other.colorTemperatureK,
        mode: other.mode,
        countdownSeconds: other.countdownSeconds,
        energy: other.energy.isEmpty ? null : {...energy, ...other.energy},
      );
}

/// Dispositivo tal como lo ve la UI.
///
/// [id] tiene el formato `<adapterId>:<idNativo>` y es estable aunque cambie
/// la IP. No contiene secretos (nunca local keys ni tokens).
class Device {
  const Device({
    required this.id,
    required this.adapterId,
    required this.name,
    required this.kind,
    required this.capabilities,
    required this.state,
    required this.online,
    required this.connectivity,
    this.room,
    this.model,
  });

  final String id;
  final String adapterId;
  final String name;
  final String? room;
  final String? model;
  final DeviceKind kind;
  final List<Capability> capabilities;
  final DeviceState state;
  final bool online;
  final Connectivity connectivity;

  Device copyWith({
    String? name,
    String? room,
    List<Capability>? capabilities,
    DeviceState? state,
    bool? online,
    Connectivity? connectivity,
  }) {
    return Device(
      id: id,
      adapterId: adapterId,
      name: name ?? this.name,
      room: room ?? this.room,
      model: model,
      kind: kind,
      capabilities: capabilities ?? this.capabilities,
      state: state ?? this.state,
      online: online ?? this.online,
      connectivity: connectivity ?? this.connectivity,
    );
  }
}
