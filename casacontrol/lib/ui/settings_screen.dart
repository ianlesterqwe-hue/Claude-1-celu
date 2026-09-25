import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'diagnostics/tuya_diagnostics_screen.dart';
import 'diagnostics/yeelight_diagnostics_screen.dart';
import 'tuya/share_home_screen.dart';
import 'tuya/tuya_login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  void _push(BuildContext context, Widget screen) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final tuya = controller.tuya;
        return Scaffold(
          appBar: AppBar(title: const Text('Configuración')),
          body: ListView(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.science_outlined),
                title: const Text('Modo Demo'),
                subtitle:
                    const Text('Dispositivos simulados, sin red ni cuentas'),
                value: controller.demoMode,
                onChanged: controller.setDemoMode,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Cuenta Tuya de CasaControl'),
                subtitle: Text(switch (tuya) {
                  null => 'No disponible en Modo Demo',
                  _ when !tuya.configured => 'SDK no configurado en este APK',
                  _ when tuya.loggedIn => 'Sesión iniciada',
                  _ => 'Sin sesión',
                }),
                enabled: tuya != null && tuya.configured,
                onTap: tuya == null
                    ? null
                    : () => _push(context,
                        TuyaLoginScreen(controller: controller)),
              ),
              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: const Text('Compartir casa'),
                subtitle: const Text('Invitar a otra persona (Tuya)'),
                enabled: tuya != null && tuya.loggedIn,
                onTap: () =>
                    _push(context, ShareHomeScreen(controller: controller)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: const Text('Diagnóstico Yeelight'),
                subtitle: const Text('Descubrimiento LAN y prueba directa'),
                onTap: () =>
                    _push(context, const YeelightDiagnosticsScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.bluetooth_searching),
                title: const Text('Diagnóstico Tuya'),
                subtitle: const Text('Product ID, categoría, Data Points'),
                onTap: () => _push(
                    context, TuyaDiagnosticsScreen(controller: controller)),
              ),
            ],
          ),
        );
      },
    );
  }
}
