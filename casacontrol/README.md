# CasaControl

App Android (Flutter) para controlar en una sola pantalla, sin publicidad
ni notificaciones de marketing:

| Dispositivo | Ecosistema | Control |
|---|---|---|
| Yeelight LED Bulb 1S | Yeelight | **LAN directa** (protocolo oficial, sin nube) |
| WiFi Plug 3 | Tuya | SmartLife App SDK (LAN/Cloud) |
| Beacon RGBCW 2 | Tuya | SmartLife App SDK (Bluetooth / Beacon) |

## Estado

- ✅ Arquitectura, Modo Demo, UI (Casa, Control, Información del
  dispositivo, Configuración).
- ✅ Adaptador Yeelight LAN completo, con tests de extremo a extremo contra
  una ampolleta simulada. Falta probarlo con la 1S real.
- 🟡 Tuya: mapeo de DPs, adaptador Dart, canal y servicio Kotlin escritos.
  Falta el proyecto Tuya (AppKey, AppSecret, AAR) para compilarlo contra
  el SDK real.

Detalle: [docs/ROADMAP.md](docs/ROADMAP.md).

## Documentación

- [docs/RESEARCH.md](docs/RESEARCH.md): Fase 0. Cuentas Tuya y migración,
  compartir, Beacon, protocolo Yeelight.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/DEVICE_INTEGRATION.md](docs/DEVICE_INTEGRATION.md): datos reales
  de los tres dispositivos.
- [docs/TUYA_SETUP.md](docs/TUYA_SETUP.md): configurar el SDK de Tuya.

## Desarrollo

```bash
cd casacontrol
flutter pub get
flutter analyze
flutter test
flutter run                              # dispositivos reales
flutter run --dart-define=DEMO_MODE=true # Modo Demo
flutter build apk --release              # sin Tuya: variante stub
```

Para probar la Yeelight: activar **Control LAN** en la app Yeelight y
conectar el teléfono a la misma Wi-Fi. Luego ir a Configuración →
Diagnóstico Yeelight.
