import 'package:flutter/material.dart';

import '../../app_controller.dart';

/// Inicio de sesión / registro en la cuenta de CasaControl.
///
/// Importante: esta NO es la cuenta de la app Tuya Smart. Las apps creadas
/// con el SDK tienen su propio sistema de cuentas (ver docs/RESEARCH.md).
class TuyaLoginScreen extends StatefulWidget {
  const TuyaLoginScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<TuyaLoginScreen> createState() => _TuyaLoginScreenState();
}

class _TuyaLoginScreenState extends State<TuyaLoginScreen> {
  final _country = TextEditingController(text: '56');
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    for (final c in [_country, _email, _password, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _do(Future<void> Function() action, String ok) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) setState(() => _message = ok);
    } catch (e) {
      if (mounted) setState(() => _message = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tuya = widget.controller.tuya!;
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta CasaControl')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Esta cuenta es propia de CasaControl. La cuenta de Tuya Smart '
            'no sirve aquí: los dispositivos se vinculan una vez a esta '
            'cuenta (ver guía de migración).',
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Iniciar sesión')),
              ButtonSegment(value: true, label: Text('Crear cuenta')),
            ],
            selected: {_register},
            onSelectionChanged: (s) => setState(() => _register = s.first),
          ),
          TextField(
            controller: _country,
            decoration: const InputDecoration(labelText: 'Código de país'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Correo'),
            keyboardType: TextInputType.emailAddress,
          ),
          TextField(
            controller: _password,
            decoration: const InputDecoration(labelText: 'Contraseña'),
            obscureText: true,
          ),
          if (_register) ...[
            TextField(
              controller: _code,
              decoration:
                  const InputDecoration(labelText: 'Código de verificación'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _do(
                      () => tuya.platform
                          .sendEmailCode(_country.text, _email.text.trim()),
                      'Código enviado al correo'),
              child: const Text('Enviar código'),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _do(() async {
                      if (_register) {
                        await tuya.platform.registerWithEmail(_country.text,
                            _email.text.trim(), _password.text, _code.text);
                      }
                      await tuya.login(
                          _country.text, _email.text.trim(), _password.text);
                      await widget.controller.registry.refresh();
                    }, 'Sesión iniciada'),
            child: Text(_register ? 'Crear cuenta' : 'Iniciar sesión'),
          ),
          if (_message != null)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_message!)),
        ],
      ),
    );
  }
}
