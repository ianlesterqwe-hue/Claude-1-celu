import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'yeelight_protocol.dart';

class YeelightException implements Exception {
  YeelightException(this.message, {this.code});
  final String message;
  final int? code;

  @override
  String toString() =>
      'YeelightException(${code == null ? '' : '$code: '}$message)';
}

/// Conexión TCP con una ampolleta: correlaciona respuestas por `id`,
/// publica notificaciones `props` y respeta el límite de comandos.
class YeelightConnection {
  YeelightConnection._(this._socket, this.host, this.port, this._limiter) {
    _socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onLine, onDone: _onClosed, onError: (_) => _onClosed());
  }

  static Future<YeelightConnection> connect(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 5),
    RateLimiter? limiter,
  }) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.setOption(SocketOption.tcpNoDelay, true);
      return YeelightConnection._(socket, host, port,
          limiter ?? RateLimiter(yeelightMaxCommandsPerMinute - 4));
    } on SocketException catch (e) {
      throw YeelightException(
          'No se pudo conectar a $host:$port. ¿Está activado "Control LAN" '
          'en la app Yeelight? (${e.message})');
    }
  }

  final Socket _socket;
  final String host;
  final int port;
  final RateLimiter _limiter;
  final _pending = <int, Completer<List<String>>>{};
  final _notifications = StreamController<Map<String, String>>.broadcast();
  final _closed = Completer<void>();
  var _nextId = 1;

  Stream<Map<String, String>> get notifications => _notifications.stream;
  Future<void> get done => _closed.future;
  bool get isClosed => _closed.isCompleted;

  Future<List<String>> send(
    String method,
    List<Object> params, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (isClosed) throw YeelightException('Conexión cerrada');
    await _limiter.acquire();
    final id = _nextId++;
    final completer = Completer<List<String>>();
    _pending[id] = completer;
    _socket.write(encodeCommand(id, method, params));
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      throw YeelightException('Sin respuesta a $method');
    } finally {
      _pending.remove(id);
    }
  }

  Future<Map<String, String>> getProps(List<String> names) async =>
      zipProps(names, await send('get_prop', names));

  void _onLine(String line) {
    switch (YeelightMessage.parse(line)) {
      case YeelightResult(:final id, :final result):
        _pending[id]?.complete(result);
      case YeelightError(:final id, :final code, :final message):
        _pending[id]?.completeError(YeelightException(message, code: code));
      case YeelightNotification(:final props):
        if (!_notifications.isClosed) _notifications.add(props);
      case null:
        break;
    }
  }

  void _onClosed() {
    if (_closed.isCompleted) return;
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(YeelightException('Conexión cerrada'));
      }
    }
    _pending.clear();
    _notifications.close();
    _closed.complete();
  }

  Future<void> close() async {
    _socket.destroy();
    _onClosed();
  }
}

/// Ventana deslizante: como máximo [perMinute] adquisiciones cada 60 s.
class RateLimiter {
  RateLimiter(this.perMinute, {this.window = const Duration(minutes: 1)});

  final int perMinute;
  final Duration window;
  final _stamps = Queue<DateTime>();

  Future<void> acquire() async {
    while (true) {
      final now = DateTime.now();
      while (_stamps.isNotEmpty && now.difference(_stamps.first) >= window) {
        _stamps.removeFirst();
      }
      if (_stamps.length < perMinute) {
        _stamps.addLast(now);
        return;
      }
      await Future<void>.delayed(window - now.difference(_stamps.first));
    }
  }
}
