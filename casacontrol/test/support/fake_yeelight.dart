import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Ampolleta Yeelight simulada que habla el protocolo LAN oficial:
/// responde M-SEARCH por UDP y comandos JSON por TCP, y emite
/// notificaciones `props` como la ampolleta real.
class FakeYeelight {
  FakeYeelight._(this.udp, this.tcp);

  static Future<FakeYeelight> start({String id = '0x0000000012345678'}) async {
    final udp = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final tcp = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeYeelight._(udp, tcp)..id = id;
    udp.listen((e) {
      if (e != RawSocketEvent.read) return;
      final dg = udp.receive();
      if (dg == null) return;
      final msg = utf8.decode(dg.data);
      if (msg.startsWith('M-SEARCH') && msg.contains('wifi_bulb')) {
        fake.searches++;
        udp.send(utf8.encode(fake.discoveryResponse()), dg.address, dg.port);
      }
    });
    tcp.listen(fake._onClient);
    return fake;
  }

  final RawDatagramSocket udp;
  ServerSocket tcp;
  late String id;
  int searches = 0;
  final commands = <Map<String, dynamic>>[];
  final _clients = <Socket>[];

  final props = <String, String>{
    'power': 'off',
    'bright': '50',
    'ct': '4000',
    'rgb': '16711680',
    'hue': '0',
    'sat': '100',
    'color_mode': '2',
    'name': 'Salon',
    'flowing': '0',
    'delayoff': '0',
    'music_on': '0',
  };

  int get udpPort => udp.port;

  String discoveryResponse() => 'HTTP/1.1 200 OK\r\n'
      'Cache-Control: max-age=3600\r\n'
      'Location: yeelight://127.0.0.1:${tcp.port}\r\n'
      'Server: POSIX UPnP/1.0 YGLC/1\r\n'
      'id: $id\r\n'
      'model: color4\r\n'
      'fw_ver: 38\r\n'
      'support: get_prop set_default set_power toggle set_bright start_cf '
      'stop_cf set_scene cron_add cron_get cron_del set_ct_abx set_rgb '
      'set_hsv set_adjust adjust_bright adjust_ct adjust_color set_music '
      'set_name\r\n'
      'power: ${props['power']}\r\n'
      'bright: ${props['bright']}\r\n'
      'color_mode: ${props['color_mode']}\r\n'
      'ct: ${props['ct']}\r\n'
      'rgb: ${props['rgb']}\r\n'
      'hue: ${props['hue']}\r\n'
      'sat: ${props['sat']}\r\n'
      'name: ${props['name']}\r\n'
      '\r\n';

  void _onClient(Socket s) {
    _clients.add(s);
    s
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _handle(s, line), onDone: () => _clients.remove(s));
  }

  void _handle(Socket s, String line) {
    final cmd = jsonDecode(line) as Map<String, dynamic>;
    commands.add(cmd);
    final id = cmd['id'];
    final params = cmd['params'] as List;
    void ok() => s.write('${jsonEncode({'id': id, 'result': ['ok']})}\r\n');
    void err(String m) => s.write(
        '${jsonEncode({'id': id, 'error': {'code': -1, 'message': m}})}\r\n');
    void notify(Map<String, String> changed) {
      props.addAll(changed);
      final n = '${jsonEncode({'method': 'props', 'params': changed})}\r\n';
      for (final c in _clients) {
        c.write(n);
      }
    }

    final on = props['power'] == 'on';
    switch (cmd['method']) {
      case 'get_prop':
        s.write('${jsonEncode({
              'id': id,
              'result': [for (final p in params) props[p] ?? ''],
            })}\r\n');
      case 'set_power':
        ok();
        notify({'power': params[0] as String});
      case 'set_bright' when on:
        ok();
        notify({'bright': '${params[0]}'});
      case 'set_ct_abx' when on:
        ok();
        notify({'ct': '${params[0]}', 'color_mode': '2'});
      case 'set_hsv' when on:
        ok();
        notify({
          'hue': '${params[0]}',
          'sat': '${params[1]}',
          'color_mode': '3',
        });
      case 'set_bright' || 'set_ct_abx' || 'set_hsv':
        err('client quota exceeded? no: device is off');
      case 'cron_add' || 'cron_del':
        ok();
      default:
        err('method not supported');
    }
  }

  /// Simula un cambio de IP/puerto: cierra el servidor TCP y abre otro.
  Future<void> moveTcp() async {
    for (final c in [..._clients]) {
      c.destroy();
    }
    await tcp.close();
    tcp = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    tcp.listen(_onClient);
  }

  Future<void> close() async {
    for (final c in [..._clients]) {
      c.destroy();
    }
    udp.close();
    await tcp.close();
  }
}
