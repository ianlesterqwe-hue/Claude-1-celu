import '../models/command.dart';
import '../models/device.dart';
import '../models/diagnostics.dart';

/// Contrato que implementa cada ecosistema (Yeelight, Tuya, Demo).
///
/// La UI interactúa exclusivamente con esta interfaz (a través de
/// DeviceRegistry). Los detalles de protocolo quedan dentro del adaptador.
abstract class DeviceAdapter {
  /// Prefijo de los ids de dispositivo: `yeelight`, `tuya`, `demo`.
  String get id;

  String get displayName;

  /// Emite la lista completa de dispositivos de este adaptador cada vez que
  /// algo cambia (descubrimiento, estado, online/offline).
  Stream<List<Device>> get devices;

  /// Última lista conocida.
  List<Device> get currentDevices;

  Future<void> start();

  /// Vuelve a descubrir / refrescar estados.
  Future<void> refresh();

  /// Ejecuta una orden. Lanza [DeviceCommandException] si falla.
  Future<void> execute(String deviceId, DeviceCommand command);

  Future<List<DiagnosticsSection>> diagnostics(String deviceId);

  Future<void> dispose();
}

class DeviceCommandException implements Exception {
  DeviceCommandException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => 'DeviceCommandException: $message'
      '${cause == null ? '' : ' ($cause)'}';
}
