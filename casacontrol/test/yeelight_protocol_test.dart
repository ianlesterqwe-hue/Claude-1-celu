import 'package:casacontrol/adapters/yeelight/yeelight_protocol.dart';
import 'package:casacontrol/core/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YeelightDiscoveryInfo.parse', () {
    const response = 'HTTP/1.1 200 OK\r\n'
        'Cache-Control: max-age=3600\r\n'
        'Date: \r\n'
        'Ext: \r\n'
        'Location: yeelight://192.168.1.239:55443\r\n'
        'Server: POSIX UPnP/1.0 YGLC/1\r\n'
        'id: 0x000000000015243f\r\n'
        'model: color\r\n'
        'fw_ver: 18\r\n'
        'support: get_prop set_default set_power toggle set_bright start_cf '
        'stop_cf set_scene cron_add cron_get cron_del set_ct_abx set_rgb\r\n'
        'power: on\r\n'
        'bright: 100\r\n'
        'color_mode: 2\r\n'
        'ct: 4000\r\n'
        'rgb: 16711680\r\n'
        'hue: 100\r\n'
        'sat: 35\r\n'
        'name: my_bulb\r\n';

    test('lee id, IP, puerto, modelo, firmware, métodos y props', () {
      final info = YeelightDiscoveryInfo.parse(response)!;
      expect(info.id, '0x000000000015243f');
      expect(info.host, '192.168.1.239');
      expect(info.port, 55443);
      expect(info.model, 'color');
      expect(info.firmwareVersion, '18');
      expect(info.support, contains('set_ct_abx'));
      expect(info.support, isNot(contains('set_hsv')));
      expect(info.props['power'], 'on');
      expect(info.name, 'my_bulb');
    });

    test('acepta NOTIFY de anuncio', () {
      final notify = response.replaceFirst('HTTP/1.1 200 OK', 'NOTIFY * HTTP/1.1');
      expect(YeelightDiscoveryInfo.parse(notify), isNotNull);
    });

    test('rechaza mensajes que no son Yeelight', () {
      expect(YeelightDiscoveryInfo.parse('M-SEARCH * HTTP/1.1\r\n'), isNull);
      expect(
          YeelightDiscoveryInfo.parse(
              'HTTP/1.1 200 OK\r\nLocation: http://x:1\r\nid: 1\r\n'),
          isNull);
    });
  });

  group('mensajes TCP', () {
    test('codifica comando con CRLF', () {
      expect(encodeCommand(1, 'set_power', ['on', 'smooth', 500]),
          '{"id":1,"method":"set_power","params":["on","smooth",500]}\r\n');
    });

    test('parsea resultado, error y notificación', () {
      expect(YeelightMessage.parse('{"id":1, "result":["ok"]}'),
          isA<YeelightResult>().having((r) => r.result, 'result', ['ok']));
      expect(
          YeelightMessage.parse(
              '{"id":2, "error":{"code":-1, "message":"unsupported method"}}'),
          isA<YeelightError>()
              .having((e) => e.message, 'message', 'unsupported method'));
      final n = YeelightMessage.parse(
          '{"method":"props","params":{"power":"on", "bright": "10"}}');
      expect(n, isA<YeelightNotification>());
      expect((n as YeelightNotification).props, {'power': 'on', 'bright': '10'});
      expect(YeelightMessage.parse('basura'), isNull);
    });

    test('efecto: sudden si no hay transición, mínimo 30 ms si smooth', () {
      expect(effectParams(null), ['sudden', 0]);
      expect(effectParams(const Duration(milliseconds: 10)), ['smooth', 30]);
      expect(effectParams(const Duration(milliseconds: 500)), ['smooth', 500]);
    });
  });

  group('estado', () {
    test('modo CT', () {
      final s = stateFromProps(
          {'power': 'on', 'bright': '70', 'ct': '2700', 'color_mode': '2'});
      expect(s.power, isTrue);
      expect(s.brightness, 70);
      expect(s.colorTemperatureK, 2700);
      expect(s.mode, LightMode.white);
    });

    test('modo RGB convierte a HSV', () {
      final s = stateFromProps({'color_mode': '1', 'rgb': '255'});
      expect(s.mode, LightMode.color);
      expect(s.color, const HsvColor(240, 100));
    });

    test('get_prop: "" = no soportada', () {
      expect(zipProps(['power', 'music_on'], ['on', '']), {'power': 'on'});
    });

    test('rgb <-> hsv', () {
      expect(hsvToRgb(const HsvColor(0, 100)), 0xFF0000);
      expect(hsvToRgb(const HsvColor(120, 100)), 0x00FF00);
      expect(rgbToHsv(0x0000FF), const HsvColor(240, 100));
      expect(rgbToHsv(0xFFFFFF), const HsvColor(0, 0));
    });
  });
}
