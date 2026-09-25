# Arquitectura

```
┌──────────────────────────── Flutter (Dart) ────────────────────────────┐
│ UI (lib/ui)                                                            │
│  Casa · Control · Información del dispositivo · Configuración          │
│  Diagnóstico Yeelight · Diagnóstico Tuya · Compartir casa              │
│                 │ sólo conoce Device / Capability / DeviceCommand      │
│                 ▼                                                      │
│ DeviceRegistry (lib/core) ── une la lista de todos los adaptadores     │
│                 │                                                      │
│      ┌──────────┼──────────────┬───────────────────┐                   │
│      ▼          ▼              ▼                   │                   │
│ DemoAdapter  YeelightAdapter  TuyaAdapter          │  DeviceAdapter    │
│              │ (Dart puro)    │ mapea DP ⇄ capacidad                   │
│              │ UDP 1982 +     │ (TuyaDpMapping, por código)            │
│              │ TCP 55443      │                                        │
└──────────────┼────────────────┼────────────────────────────────────────┘
               │                │ MethodChannel  "casacontrol/tuya"
               │                │ EventChannel   "casacontrol/tuya/events"
               ▼                ▼
        Yeelight 1S      TuyaPlatformService (Kotlin)
        (LAN directa)           │
                                ▼
                     Tuya SmartLife App SDK ──▶ WiFi Plug 3 (LAN/Cloud)
                                             ──▶ Beacon RGBCW 2 (BLE)
```

## Principios

- **La UI sólo ve `DeviceAdapter`** (a través de `DeviceRegistry`). No
  conoce métodos Yeelight, DP IDs ni el SDK de Tuya.
- **Capacidades genéricas** (`lib/core/models/capability.dart`):
  `PowerCapability`, `BrightnessCapability`, `ColorCapability`,
  `ColorTemperatureCapability`, `TransitionCapability`,
  `CountdownCapability`, `ScheduleCapability`, `EnergyMeterCapability`
  y `NativeScenesCapability`. La UI dibuja un control sólo si la capacidad
  existe. Por ejemplo, las métricas eléctricas aparecen sólo si el enchufe
  expone esos DPs.
- **Conectividad visible**: cada `Device` indica cómo se controla (`LAN`,
  `Bluetooth`, `Tuya Cloud`, `Tuya Cloud / LAN`). El detalle técnico está
  en "Información del dispositivo".
- **Sin secretos en Dart**: la capa nativa nunca envía local keys, tokens
  ni datos del `User`. Los IDs se muestran censurados (`bf12…cdef`).
- **Identidad estable**: `yeelight:<id>` o `tuya:<devId>`. La IP de la
  Yeelight no se guarda: se toma del último descubrimiento.

## Yeelight (lib/adapters/yeelight)

| Archivo | Rol |
|---|---|
| `yeelight_protocol.dart` | Implementación pura del protocolo: parseo del descubrimiento, codificación de comandos, respuestas y notificaciones, props → `DeviceState`, RGB⇄HSV. Sin sockets. |
| `yeelight_discovery.dart` | M-SEARCH activo + escucha de NOTIFY multicast. |
| `yeelight_connection.dart` | TCP: correlación por `id`, timeouts, notificaciones `props`, limitador 56 cmd/min. |
| `yeelight_adapter.dart` | `DeviceAdapter`: redescubre cada 60 s, reconecta con backoff (2/5/15/30/60 s) y, si la IP cambió, redescubre antes de reintentar. Si la luz está apagada, la enciende antes de cambiar color o brillo. |

En Android, `MainActivity.kt` toma un `WifiManager.MulticastLock` para
recibir los NOTIFY.

## Tuya

| Capa | Archivo |
|---|---|
| Dart: canal | `lib/adapters/tuya/tuya_platform.dart` (`initialize`, `login`, `getHomes`, `getDevices`, `connectDevice`, `publishDataPoints`, `subscribeDeviceState`, `createSchedule`, `shareHome`, `joinHome`, …) |
| Dart: mapeo | `lib/adapters/tuya/tuya_dp_mapper.dart`: busca los códigos estándar (`switch_led`, `bright_value_v2`, `colour_data_v2`, `switch_1`, `cur_power`…) en el esquema real y usa el DP ID, rango y escala de ese esquema. |
| Dart: adaptador | `lib/adapters/tuya/tuya_adapter.dart` |
| Kotlin: contrato | `android/app/src/main/kotlin/.../tuya/TuyaService.kt` |
| Kotlin: SDK real | `android/app/src/tuya/kotlin/.../tuya/TuyaPlatformService.kt` |
| Kotlin: stub | `android/app/src/tuyaStub/kotlin/.../tuya/TuyaServiceFactory.kt` |

La variante se elige en `android/app/build.gradle.kts` según
`casacontrol.tuya.enabled` en `local.properties`. Sin credenciales Tuya el
APK igual compila, y Yeelight y Demo funcionan.

## Demo Mode

`DemoAdapter` simula los tres dispositivos del proyecto con sus capacidades
esperadas. Se activa desde Configuración, o al compilar con
`--dart-define=DEMO_MODE=true`.

## Pruebas

- `test/yeelight_protocol_test.dart`: parseo y codificación del protocolo.
- `test/yeelight_adapter_test.dart`: prueba de extremo a extremo contra una
  ampolleta simulada (`test/support/fake_yeelight.dart`) que habla UDP y
  TCP reales en loopback. Cubre descubrimiento, ON/OFF, brillo, color,
  temperatura, encendido previo, cambio de dirección y límite de comandos.
- `test/tuya_dp_mapper_test.dart`: mapeo con DP IDs inventados, para
  comprobar que nunca se depende del número.
- `test/home_screen_test.dart`: UI en Modo Demo.
