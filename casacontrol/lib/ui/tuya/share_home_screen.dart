import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_controller.dart';

/// Compartir casa usando la función oficial de miembros de Home de Tuya
/// (código de invitación). No se intercambian tokens ni claves propias.
///
/// Teléfono A (OWNER): "Generar invitación" → comparte el código.
/// Teléfono B (MEMBER): inicia sesión con SU cuenta → "Unirme con código".
class ShareHomeScreen extends StatefulWidget {
  const ShareHomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ShareHomeScreen> createState() => _ShareHomeScreenState();
}

class _ShareHomeScreenState extends State<ShareHomeScreen> {
  final _code = TextEditingController();
  String? _invitation;
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _do(Future<void> Function() f) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await f();
    } catch (e) {
      if (mounted) setState(() => _message = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tuya = widget.controller.tuya!;
    final homeId = tuya.currentHomeId;
    return Scaffold(
      appBar: AppBar(title: const Text('Compartir casa')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Invitar persona',
              style: Theme.of(context).textTheme.titleMedium),
          const Text(
              'La otra persona instala CasaControl, crea su propia cuenta y '
              'escribe este código en "Unirme con código".'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy || homeId == null
                ? null
                : () => _do(() async {
                      final code = await tuya.platform.shareHome(homeId);
                      if (mounted) setState(() => _invitation = code);
                    }),
            child: const Text('Generar invitación'),
          ),
          if (_invitation != null)
            ListTile(
              title: SelectableText(_invitation!,
                  style: Theme.of(context).textTheme.headlineSmall),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: _invitation!)),
              ),
            ),
          const Divider(height: 32),
          Text('Unirme con código',
              style: Theme.of(context).textTheme.titleMedium),
          TextField(
            controller: _code,
            decoration:
                const InputDecoration(labelText: 'Código de invitación'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _do(() async {
                      await tuya.platform.joinHome(_code.text.trim());
                      await widget.controller.registry.refresh();
                      if (mounted) {
                        setState(() => _message = 'Te uniste a la casa');
                      }
                    }),
            child: const Text('Unirme'),
          ),
          if (_message != null)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_message!)),
          const SizedBox(height: 24),
          const Text(
            'La Yeelight se controla por LAN: cualquier teléfono con '
            'CasaControl en la misma Wi-Fi la descubre sin cuenta.',
          ),
        ],
      ),
    );
  }
}
