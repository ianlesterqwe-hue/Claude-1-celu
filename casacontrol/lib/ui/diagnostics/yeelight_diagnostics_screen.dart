import 'package:flutter/material.dart';

import '../../adapters/yeelight/yeelight_connection.dart';
import '../../adapters/yeelight/yeelight_discovery.dart';
import '../../adapters/yeelight/yeelight_protocol.dart';

/// Diagnóstico Yeelight independiente de la UI principal: usa directamente
/// el descubrimiento oficial y abre su propia conexión TCP.
class YeelightDiagnosticsScreen extends StatefulWidget {
  const YeelightDiagnosticsScreen({super.key});

  @override
  State<YeelightDiagnosticsScreen> createState() =>
      _YeelightDiagnosticsScreenState();
}

class _YeelightDiagnosticsScreenState extends State<YeelightDiagnosticsScreen> {
  final _discovery = YeelightDiscovery(listenForAdvertisements: false);
  final _connections = <String, YeelightConnection>{};
  final _status = <String, String>{};
  List<YeelightDiscoveryInfo> _found = [];
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    for (final c in _connections.values) {
      c.close();
    }
    _discovery.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final found = await _discovery.search();
      if (!mounted) return;
      setState(() => _found = found);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<YeelightConnection> _conn(YeelightDiscoveryInfo info) async {
    final existing = _connections[info.id];
    if (existing != null && !existing.isClosed) return existing;
    final c = await YeelightConnection.connect(info.host, info.port);
    _connections[info.id] = c;
    return c;
  }

  Future<void> _run(YeelightDiscoveryInfo info, String label,
      Future<String> Function(YeelightConnection) action) async {
    setState(() => _status[info.id] = '$label…');
    try {
      final result = await action(await _conn(info));
      if (mounted) setState(() => _status[info.id] = '$label: $result');
    } catch (e) {
      if (mounted) setState(() => _status[info.id] = '$label falló: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico Yeelight'),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            onPressed: _searching ? null : _search,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_searching) const LinearProgressIndicator(),
          if (_error != null) Text('Error: $_error'),
          if (!_searching && _found.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No se encontraron ampolletas.\n\n'
                '• El teléfono y la ampolleta deben estar en la misma red Wi-Fi '
                '(2,4 GHz, sin aislamiento de clientes).\n'
                '• En la app Yeelight: dispositivo → ⋯ → "Control LAN" → activado.',
              ),
            ),
          for (final info in _found) _card(info),
        ],
      ),
    );
  }

  Widget _card(YeelightDiscoveryInfo info) {
    final p = info.props;
    final mode = switch (p['color_mode']) {
      '1' => 'RGB',
      '2' => 'Temperatura de color',
      '3' => 'HSV',
      _ => '—',
    };
    String row(String k, String? v) => '$k: ${v == null || v.isEmpty ? '—' : v}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.name.isEmpty ? '(sin nombre)' : info.name,
                style: Theme.of(context).textTheme.titleMedium),
            Text(row('Modelo', info.model)),
            Text(row('IP', '${info.host}:${info.port}')),
            Text(row('Firmware', info.firmwareVersion)),
            Text(row('Encendida', p['power'])),
            Text(row('Brillo', p['bright'] == null ? null : '${p['bright']}%')),
            Text(row('Modo de color', mode)),
            Text(row('Temperatura de color',
                p['ct'] == null ? null : '${p['ct']} K')),
            Text(row(
                'Control LAN',
                switch (_connections[info.id]) {
                  final c? when !c.isClosed => 'disponible (conectado)',
                  _ => 'anunciado; usar "Probar conexión"',
                })),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => _run(info, 'Probar conexión', (c) async {
                    final props = await c.getProps(yeelightProps);
                    return 'OK · ${props.entries.map((e) => '${e.key}=${e.value}').join(', ')}';
                  }),
                  child: const Text('Probar conexión'),
                ),
                OutlinedButton(
                  onPressed: () => _run(info, 'Encender', (c) async {
                    return (await c.send('set_power', ['on', 'smooth', 300]))
                        .join();
                  }),
                  child: const Text('Encender'),
                ),
                OutlinedButton(
                  onPressed: () => _run(info, 'Apagar', (c) async {
                    return (await c.send('set_power', ['off', 'smooth', 300]))
                        .join();
                  }),
                  child: const Text('Apagar'),
                ),
              ],
            ),
            if (_status[info.id] case final s?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(s,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
