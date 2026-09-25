# Integración de dispositivos reales

> Los datos se llenan con la información **real** que entregan los
> dispositivos (Fases 2 y 4). Nada de esta tabla se asume. Los campos
> «pendiente» todavía no se consultaron.
>
> Nunca anotar aquí: Local Key, tokens, contraseñas ni el Device ID
> completo. Usar la versión censurada que muestra la app.

## A) Yeelight LED Bulb 1S

Fuente: Configuración → Diagnóstico Yeelight.

| Campo | Valor |
|---|---|
| Nombre | pendiente |
| Modelo (`model`) | pendiente |
| Firmware (`fw_ver`) | pendiente |
| ID (censurado) | pendiente |
| Control LAN disponible | pendiente |
| Métodos (`support`) | pendiente |
| Rango CT observado | pendiente (la especificación indica 1700–6500 K) |

Capacidades esperadas → cómo se implementan:

| CasaControl | Yeelight |
|---|---|
| PowerCapability | `set_power` |
| BrightnessCapability | `set_bright` |
| ColorCapability | `set_hsv` (o `set_rgb` si no está en `support`) |
| ColorTemperatureCapability | `set_ct_abx` |
| TransitionCapability | efecto `smooth` + duración |
| CountdownCapability | `cron_add` tipo 0 / `cron_del` |

## B) Beacon RGBCW 2 (Tuya)

Fuente: Configuración → Diagnóstico Tuya (después de emparejarlo con la
cuenta de CasaControl).

| Campo | Valor |
|---|---|
| Nombre | Beacon RGBCW 2 |
| Device ID (censurado) | pendiente |
| Product ID (PID) | pendiente |
| Categoría | pendiente |
| Comunicación (BLE / Tuya Mesh / SIG Mesh / Beacon / combo) | pendiente |
| Tipo Bluetooth | pendiente |
| Online | pendiente |

Data Points reales:

| DP ID | Código | Tipo | Modo | Rango / valores | Capacidad CasaControl |
|---|---|---|---|---|---|
| pendiente | | | | | |

## C) WiFi Plug 3 (Tuya)

| Campo | Valor |
|---|---|
| Nombre | WiFi Plug 3 |
| Device ID (censurado) | pendiente |
| Product ID (PID) | pendiente |
| Categoría | pendiente |
| Comunicación | pendiente (se espera Wi-Fi) |
| Control local (LAN) | pendiente |

Data Points reales:

| DP ID | Código | Tipo | Modo | Rango / escala / unidad | Capacidad CasaControl |
|---|---|---|---|---|---|
| pendiente | | | | | |

¿Expone medición eléctrica? pendiente. La UI la muestra sólo si
aparecen `cur_power`, `cur_current`, `cur_voltage` o `add_ele` en el
esquema real.

## Tabla de mapeo usada por el código (por código, no por número)

| Capacidad | Códigos buscados (en orden) |
|---|---|
| Power | `switch_led`, `switch_1`, `switch`, `led_switch` |
| Modo | `work_mode` (`white` / `colour` / `scene` / `music`) |
| Brillo | `bright_value_v2`, `bright_value` (usa min/max del esquema) |
| Temperatura | `temp_value_v2`, `temp_value` (relativa; se muestra como K aproximado) |
| Color | `colour_data_v2` (HHHHSSSSVVVV), `colour_data` (RRGGBBHHHHSSVV) |
| Temporizador | `countdown_1`, `countdown` |
| Medición | `cur_power`, `cur_current`, `cur_voltage`, `add_ele` (con `scale`) |
| Escenas nativas | `scene_data_v2`, `scene_data` |

Si un dispositivo real usa otros códigos, se agregan a
`lib/adapters/tuya/tuya_dp_mapper.dart`, con un test, y se documentan aquí.
