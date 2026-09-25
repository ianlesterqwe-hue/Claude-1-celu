/// Capacidades genéricas de CasaControl.
///
/// Cada adaptador (Yeelight, Tuya, Demo) traduce lo que su protocolo expone
/// a este conjunto. La UI sólo mira capacidades: nunca DP IDs, métodos LAN,
/// ni nombres de protocolo.
sealed class Capability {
  const Capability();
}

class PowerCapability extends Capability {
  const PowerCapability();
}

/// Brillo en porcentaje 1..100 (la UI siempre trabaja en %).
class BrightnessCapability extends Capability {
  const BrightnessCapability();
}

/// Color por tono/saturación (HSV). El "valor" es el brillo.
class ColorCapability extends Capability {
  const ColorCapability();
}

/// Temperatura de color. Si [approximate] es true, el dispositivo no informa
/// su rango real en Kelvin y el adaptador interpola sobre un rango nominal.
class ColorTemperatureCapability extends Capability {
  const ColorTemperatureCapability({
    required this.minKelvin,
    required this.maxKelvin,
    this.approximate = false,
  });

  final int minKelvin;
  final int maxKelvin;
  final bool approximate;
}

/// El dispositivo acepta una duración de transición en los cambios.
class TransitionCapability extends Capability {
  const TransitionCapability();
}

/// Temporizador de cuenta regresiva (p. ej. "apagar en 30 min").
class CountdownCapability extends Capability {
  const CountdownCapability({this.maxSeconds = 86400});
  final int maxSeconds;
}

/// Horarios guardados en el dispositivo o en la nube del fabricante.
class ScheduleCapability extends Capability {
  const ScheduleCapability();
}

/// Métricas eléctricas. Sólo se crea con las métricas que el dispositivo
/// realmente expone; la UI muestra exclusivamente esas.
class EnergyMeterCapability extends Capability {
  const EnergyMeterCapability(this.metrics);
  final Set<EnergyMetric> metrics;
}

enum EnergyMetric {
  powerW('Potencia', 'W'),
  currentMa('Corriente', 'mA'),
  voltageV('Voltaje', 'V'),
  energyKwh('Energía acumulada', 'kWh');

  const EnergyMetric(this.label, this.unit);
  final String label;
  final String unit;
}

/// Escenas nativas del dispositivo (p. ej. escenas de iluminación Tuya).
class NativeScenesCapability extends Capability {
  const NativeScenesCapability();
}

extension CapabilitySetX on Iterable<Capability> {
  bool has<T extends Capability>() => whereType<T>().isNotEmpty;
  T? get<T extends Capability>() {
    final found = whereType<T>();
    return found.isEmpty ? null : found.first;
  }
}
