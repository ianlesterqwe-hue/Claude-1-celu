# Roadmap

Estado: ✅ hecho · 🟡 parcial / andamiaje listo · ⬜ pendiente

| Fase | Contenido | Estado |
|---|---|---|
| 0 | Investigar Yeelight LAN, Tuya SmartLife App SDK, Tuya Bluetooth/Beacon y Home/Device Sharing → [`RESEARCH.md`](RESEARCH.md) | ✅ |
| 1 | Arquitectura Flutter (`DeviceAdapter`, capacidades, `DeviceRegistry`) + Demo Mode + UI Casa/Control/Info | ✅ |
| 2 | Yeelight LAN: descubrimiento, ON/OFF, brillo, color, temperatura, transiciones, notificaciones, reconexión y pantalla de diagnóstico | ✅ en código y tests · ⬜ **probar con la 1S real** |
| 3 | Crear proyecto Tuya, configurar SmartLife App SDK ([`TUYA_SETUP.md`](TUYA_SETUP.md)) y compilar `TuyaPlatformService` contra el AAR real | 🟡 código Kotlin escrito, sin compilar contra el SDK |
| 4 | Obtener PID, categoría, comunicación y DPs reales del Beacon RGBCW 2 y del WiFi Plug 3 con la pantalla Diagnóstico Tuya → [`DEVICE_INTEGRATION.md`](DEVICE_INTEGRATION.md) | 🟡 herramienta lista; faltan los datos reales |
| 5 | WiFi Plug 3: ON/OFF, estado, reconexión, timeout, temporizador y medición si existe | 🟡 mapeo por código listo; falta el pairing en la app |
| 6 | Beacon RGBCW 2: control por SDK (sin GATT manual) + permisos BLE en tiempo de ejecución + pairing Beacon | ⬜ |
| 7 | Unificar los tres en la Home (habitaciones locales para la Yeelight, orden, persistencia) | 🟡 lista unificada por habitación |
| 8 | Escenas (multi-dispositivo en CasaControl + escenas nativas Tuya/flows Yeelight) | ⬜ |
| 9 | Horarios (timers Tuya del SDK; `cron_add` o programación local para Yeelight) | ⬜ (temporizador simple ya disponible) |
| 10 | Compartir Home con otra persona (invitación oficial de Tuya; Yeelight por LAN) | 🟡 pantalla y canal listos; falta probarlo con 2 teléfonos |
| 11 | Widgets / Quick Settings opcionales | ⬜ |
| 12 | APK release firmado | ⬜ |

## Próximo paso concreto (Fase 2 con hardware)

1. En la app Yeelight: activar **Control LAN** en la 1S.
2. `cd casacontrol && flutter run` con el teléfono en la misma Wi-Fi.
3. Configuración → **Diagnóstico Yeelight** → debería aparecer la 1S con
   IP, modelo y firmware → **Probar conexión** → **Encender** / **Apagar**.
4. Volver a Casa y probar brillo, color y temperatura.
5. Anotar el `model` y el `fw_ver` reales en `DEVICE_INTEGRATION.md`.
