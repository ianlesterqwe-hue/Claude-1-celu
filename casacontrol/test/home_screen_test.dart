import 'package:casacontrol/app_controller.dart';
import 'package:casacontrol/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Modo Demo muestra los tres dispositivos y su conectividad',
      (tester) async {
    final controller = AppController(demoMode: true);
    await tester.runAsync(controller.start);
    await tester.pumpWidget(CasaControlApp(controller: controller));
    await tester.pump();

    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('Salón'), findsOneWidget);
    expect(find.text('Yeelight 1S'), findsOneWidget);
    expect(find.text('Beacon RGBCW 2'), findsOneWidget);
    expect(find.text('WiFi Plug 3'), findsOneWidget);
    expect(find.textContaining('Blanco cálido · Brillo 70%'), findsOneWidget);
    expect(find.textContaining('Azul · Brillo 35%'), findsOneWidget);
    expect(find.text('  ·  LAN'), findsOneWidget);
    expect(find.text('  ·  Bluetooth'), findsOneWidget);
    expect(find.textContaining('Tuya Cloud / LAN'), findsOneWidget);

    // Apagar el enchufe desde la tarjeta.
    await tester.runAsync(() async {
      await tester.tap(find.byType(Switch).last);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(find.text('Apagado'), findsOneWidget);

    // Abrir el control de la Yeelight.
    await tester.tap(find.text('Yeelight 1S'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Brillo: 70%'), findsOneWidget);
    expect(find.textContaining('Temperatura de color'), findsOneWidget);

    controller.dispose();
  });
}
