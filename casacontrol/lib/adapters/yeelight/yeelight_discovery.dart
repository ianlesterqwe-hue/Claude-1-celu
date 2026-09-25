import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'yeelight_protocol.dart';

/// Descubrimiento LAN oficial de Yeelight (M-SEARCH + NOTIFY).
///
/// No hay IPs fijas: cada búsqueda devuelve la IP actual de cada ampolleta,
/// identificada por su `id`.
class YeelightDiscovery {
  YeelightDiscovery({
    InternetAddress? target,
    this.port = yeelightDiscoveryPort,
    this.listenForAdvertisements = true,
  }) : target = target ?? InternetAddress(yeelightMulticastAddress);

  final InternetAddress target;
  final int port;

  /// Escucha los NOTIFY que las ampolletas envían periódicamente al grupo
  /// multicast. En Android requiere un MulticastLock (ver MainActivity.kt).
  final bool listenForAdvertisements;

  final _found = StreamController<YeelightDiscoveryInfo>.broadcast();
  RawDatagramSocket? _advertSocket;

  /// Respuestas de búsqueda y anuncios espontáneos.
  Stream<YeelightDiscoveryInfo> get found => _found.stream;

  Future<void> startListening() async {
    if (!listenForAdvertisements || _advertSocket != null) return;
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
        reusePort: !Platform.isWindows && !Platform.isAndroid,
      );
      socket.joinMulticast(target);
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket.receive();
        if (dg == null) return;
        _handle(dg);
      });
      _advertSocket = socket;
    } on SocketException {
      // Sin multicast (p. ej. emulador): sólo quedará el M-SEARCH activo.
    }
  }

  /// Envía M-SEARCH y recolecta respuestas durante [timeout].
  /// Reintenta el envío porque UDP puede perder paquetes.
  Future<List<YeelightDiscoveryInfo>> search({
    Duration timeout = const Duration(seconds: 3),
    int attempts = 3,
  }) async {
    final results = <String, YeelightDiscoveryInfo>{};
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.multicastHops = 4;
    final done = Completer<void>();
    final sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg == null) return;
      final info = _handle(dg);
      if (info != null) results[info.id] = info;
    });
    final payload = ascii.encode(yeelightSearchMessage);
    final gap = Duration(
        milliseconds: timeout.inMilliseconds ~/ (attempts * 2).clamp(1, 100));
    for (var i = 0; i < attempts; i++) {
      socket.send(payload, target, port);
      if (i < attempts - 1) await Future<void>.delayed(gap);
    }
    Timer(timeout, () => done.complete());
    await done.future;
    await sub.cancel();
    socket.close();
    return results.values.toList();
  }

  YeelightDiscoveryInfo? _handle(Datagram dg) {
    final info = YeelightDiscoveryInfo.parse(
        utf8.decode(dg.data, allowMalformed: true));
    if (info != null && !_found.isClosed) _found.add(info);
    return info;
  }

  Future<void> dispose() async {
    _advertSocket?.close();
    _advertSocket = null;
    await _found.close();
  }
}
