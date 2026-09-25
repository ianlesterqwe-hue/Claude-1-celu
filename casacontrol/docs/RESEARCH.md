# Fase 0 — Investigación de documentación oficial

Fecha: 2026-09-25.

**Cómo se hizo:** desde el entorno de desarrollo, el proxy de red bloqueó
la lectura directa de `developer.tuya.com` y `yeelight.com`. Lo de Tuya se
obtuvo de los resúmenes de búsqueda de la documentación oficial (enlaces
abajo). Lo de Yeelight sale de la especificación pública *Yeelight WiFi
Light Inter-Operation Specification*, que es estable desde hace años. Cada
punto indica su nivel de confianza:

- ✅ confirmado en la documentación oficial o implementado y probado;
- 🔶 documentado, pero hay que verificarlo con los dispositivos reales o con
  el SDK compilado (Fases 3 y 4).

---

## 1. Yeelight — control LAN (Third-party Control Protocol)

| Tema | Detalle | |
|---|---|---|
| Activación | App Yeelight → dispositivo → ⋯ → **Control LAN** (LAN Control) = ON. Sin esto la ampolleta no abre el puerto TCP. | ✅ |
| Descubrimiento | `M-SEARCH` UDP a `239.255.255.250:1982` con `ST: wifi_bulb`. Responde por unicast con cabeceras `Location: yeelight://IP:55443`, `id`, `model`, `fw_ver`, `support`, `power`, `bright`, `color_mode`, `ct`, `rgb`, `hue`, `sat`, `name`. | ✅ |
| Anuncios | La ampolleta envía `NOTIFY * HTTP/1.1` al mismo grupo multicast (al encender y periódicamente). En Android hace falta un `MulticastLock`. | ✅ |
| Control | TCP (puerto de `Location`, normalmente 55443). Un JSON por línea terminado en `\r\n`: `{"id":1,"method":"set_power","params":["on","smooth",500]}` | ✅ |
| Respuestas | `{"id":1,"result":["ok"]}` / `{"id":1,"error":{"code":-1,"message":"..."}}` | ✅ |
| Cambios de estado | Notificación `{"method":"props","params":{...}}` a **todas** las conexiones abiertas. Así, si otro teléfono cambia la luz, CasaControl lo ve al instante. | ✅ |
| Métodos usados | `get_prop`, `set_power` (on/off + efecto + duración [+ modo]), `set_bright` (1–100), `set_rgb` (0–0xFFFFFF), `set_hsv` (hue 0–359, sat 0–100), `set_ct_abx` (1700–6500 K), `start_cf`/`stop_cf` (flujos), `cron_add`/`cron_del` (apagado diferido), `set_name` | ✅ |
| Transiciones | Efecto `"smooth"` con duración ≥ 30 ms, o `"sudden"`. | ✅ |
| Restricción | `set_bright`, `set_rgb`, `set_hsv` y `set_ct_abx` sólo se aceptan con la luz **encendida**. El adaptador enciende primero. | ✅ |
| Límites | 60 comandos/min por conexión, 144/min en total por LAN y máx. 4 conexiones simultáneas por ampolleta. Por eso los sliders envían sólo al soltar. | ✅ |
| Yeelight 1S | Modelo YLDP13YL (color). El string `model` exacto no se hardcodea: se usan los métodos anunciados en `support`. | 🔶 confirmar `model`/`fw_ver` reales en la Fase 2 |

**Compartir:** no hay cuentas ni tokens en LAN. Cualquier teléfono en la
misma Wi-Fi descubre y controla la ampolleta; las notificaciones mantienen
sincronizados a los dos teléfonos. No hace falta una nube propia.

**Riesgos:** algunos firmwares desactivan el Control LAN después de una
actualización o de un reset. Además, las redes con aislamiento de clientes
(AP isolation) o con dos bandas separadas pueden bloquear el multicast.

---

## 2. Tuya — SmartLife App SDK (Smart App SDK) para Android

| Tema | Detalle | |
|---|---|---|
| Qué es | SDK oficial Android (Kotlin/Java, `com.thingclips.smart:thingsmart`) con cuentas, Homes, habitaciones, pairing, control por DP, BLE/Mesh/Beacon, escenas, timers y compartir. **No hay SDK Dart oficial**; por eso se usa Kotlin + MethodChannel. | ✅ |
| Requisitos | Proyecto en la plataforma Tuya → AppKey + AppSecret. El AAR `security-algorithm` está atado al **nombre de paquete** y al **SHA-256 del certificado de firma** del APK. | ✅ |
| Licencia | La "Self-Developed App **Trial**" es gratuita, con límite de 20 usuarios finales registrados y 100.000 llamadas cloud/mes. Alcanza para una casa. La versión comercial cuesta alrededor de 5.000 USD/año. | 🔶 revisar condiciones vigentes al crear el proyecto |
| Cuentas | Registro/login por correo o teléfono con verificación; región por código de país. | ✅ |
| Homes/rooms | `getHomeManagerInstance().queryHomeList`, `newHomeInstance(id).getHomeDetail` → dispositivos y habitaciones. | ✅ |
| Control | `newDeviceInstance(devId).publishDps(json)`; escucha con `IDevListener.onDpUpdate/onStatusChanged/onRemoved`. El SDK elige el canal (LAN o nube) en dispositivos Wi-Fi. | ✅ |
| Esquema de DPs | `getDataInstance().getSchema(devId)` → id, code, tipo, modo, propiedades (min/max/scale/step/range). CasaControl mapea por **código**, nunca por número. | ✅ |
| Bluetooth | El escaneo de activación soporta `SINGLE` (BLE), `MESH` (Tuya mesh), `SIG_MESH` y `THING_BEACON`. | ✅ (existencia) · 🔶 (API exacta de control Beacon) |
| Timers | `getTimerInstance().addTimer(ThingTimerBuilder…)` o `DeviceTimerManager` del SDK de extensión: DPs + hora + repetición por día. | ✅ existencia · 🔶 builder exacto |
| Compartir Home | OWNER: `getMemberInstance().getInvitationMessage(homeId)` → **código de invitación**. MEMBER: `getHomeManagerInstance().joinHomeByInviteCode(code)`. También se puede cancelar y reenviar la invitación. | ✅ |
| Compartir dispositivo | "Device Sharing" por cuenta, para dispositivos sueltos. | ✅ |

### 2.1 ¿Puedo usar mi cuenta de Tuya Smart en CasaControl? — **No**

La documentación de Tuya dice que las cuentas de la **app Tuya Smart**, de
**Smart Life** y de las **apps OEM/propias** son sistemas de cuentas
**separados**. Aunque el correo y la contraseña sean iguales, una cuenta de
una app no inicia sesión en otra. Además, los datos de cada zona de
disponibilidad (América, Europa, China…) están aislados entre sí.

Con las tres opciones que se plantearon:

| Opción | Resultado |
|---|---|
| A) Importar/vincular los dispositivos actuales | ❌ No existe con el App SDK. Vincular la cuenta de la app a un **proyecto Cloud** sólo da acceso por la **Cloud API** (servidor), no dentro de una app hecha con el SDK. |
| B) Compartirlos desde Tuya Smart a CasaControl | ❌ El destinatario tiene que ser una cuenta **de la misma app**. Una cuenta de CasaControl no existe para Tuya Smart. |
| C) Desvincular y volver a emparejar desde CasaControl | ✅ **Este es el camino.** Se hace una sola vez por dispositivo. |

Procedimiento previsto (Fase 3 → 5/6):

1. En Tuya Smart, anotar el nombre y la habitación de cada dispositivo.
2. Eliminar el dispositivo de Tuya Smart ("Eliminar dispositivo" /
   "Desvincular y borrar datos").
3. Poner el dispositivo en modo emparejamiento. En el enchufe se suele
   mantener el botón hasta que parpadee rápido. En la ampolleta, se suele
   hacer ON/OFF 3 veces. El procedimiento exacto depende del modelo.
4. Emparejarlo desde CasaControl (flujo de pairing del SDK: EZ/AP para
   Wi-Fi y activador BLE/Beacon para la ampolleta).

Después de esto no hace falta Tuya Smart para el uso diario. Puede seguir
siendo útil para actualizar firmware, pero para eso habría que volver a
emparejar el dispositivo en esa app.

> Alternativa **no elegida**: usar la Cloud API con un proyecto Cloud
> vinculado a la cuenta de Tuya Smart, o el protocolo local no oficial
> (tinytuya y similares). Se descartó por las instrucciones del proyecto y
> porque exigiría manejar *local keys*. Queda anotada sólo como respaldo
> si el SDK no pudiera emparejar algún dispositivo.

### 2.2 Compartir con otra persona (Tuya)

Se usa la función oficial de **miembros de Home**:

```
Teléfono A (OWNER)                         Teléfono B (MEMBER)
Casa → Configuración → Compartir casa      instala CasaControl
  → Generar invitación  ──código──▶        crea SU cuenta CasaControl
                                           → Unirme con código
                                           → ve los dispositivos de la Home
```

- No se intercambian tokens, Device IDs ni Local Keys. El SDK autoriza al
  miembro en la nube de Tuya.
- 🔶 Hay que verificar que el miembro puede controlar el **Beacon** desde
  su teléfono. Normalmente la nube le entrega las credenciales BLE del
  dispositivo, pero conviene probarlo en la Fase 10.
- Cada persona necesita su propia cuenta. Esto cuenta para el límite de
  usuarios de la licencia Trial.

### 2.3 Beacon RGBCW 2 — qué hay que determinar

"Tuya Beacon" es un protocolo de **broadcast sobre BLE**: el teléfono (o
un control remoto) emite anuncios BLE y la ampolleta los escucha, sin una
conexión GATT clásica. Tuya lo ofrece para luces "Beacon" que se controlan
por teléfono, por control remoto Beacon y en grupos. El SDK Android incluye
`THING_BEACON` entre los tipos de escaneo. Conclusiones:

- **No** se escriben características GATT ni se adivinan UUIDs. El control
  se hace **sólo** con `publishDps` del SDK.
- El tipo real (BLE punto a punto, Tuya Mesh, SIG Mesh, Beacon o combo
  Wi-Fi+BLE) lo informa el SDK. `TuyaPlatformService.communicationOf()`
  lo expone y la pantalla **Diagnóstico Tuya** lo muestra. Se anota en
  `DEVICE_INTEGRATION.md` en la Fase 4.
- Consecuencia práctica: un dispositivo Beacon sólo se controla con el
  teléfono **cerca**, a alcance Bluetooth. Desde fuera de casa haría falta
  un gateway Bluetooth de Tuya.

### 2.4 WiFi Plug 3

- Dispositivo Wi-Fi: el SDK lo controla por LAN cuando el teléfono está en
  la misma red y por la nube en el resto de los casos. CasaControl muestra
  "Tuya Cloud / LAN" o "Tuya Cloud" según `isLocalOnline`.
- Los códigos habituales (`switch_1`, `countdown_1`, `cur_power`,
  `cur_current`, `cur_voltage`, `add_ele`) **no se asumen**. El mapeo sólo
  activa medición eléctrica si esos códigos existen en el esquema real, y
  usa su `scale` real.

---

## Fuentes

- [Tuya — SmartLife App SDK](https://developer.tuya.com/en/docs/app-development/app-sdk-smart-home?id=Kaq6lep0vc16u)
- [Tuya — Developer Guide for Android (feature overview)](https://developer.tuya.com/en/docs/app-development/android-app-sdk/featureoverview?id=Ka69nt97vtsfu)
- [Tuya — Quick Start with SmartLife App SDK for Android](https://developer.tuya.com/en/docs/app-development/tutorial-for-android-final?id=Kapicb0k79vrg)
- [Tuya — User Account Management](https://developer.tuya.com/en/docs/app-development/usermanage?id=Ka69qtzy9l8nc)
- [Tuya — What is the account system?](https://support.tuya.com/en/help/_detail/K93eolrqjoiu7)
- [Tuya — What is the difference between Tuya App and SmartLife App?](https://support.tuya.com/en/help/_detail/K9hrdz10p224e)
- [Tuya — How to access devices added through the SmartLife app… (Cloud project linking)](https://support.tuya.com/en/help/_detail/Kf9vpx3t5qgpl)
- [Tuya — Home Member Management](https://developer.tuya.com/en/docs/app-development/extension-family-member?id=Kcy2iwdhz60pm)
- [Tuya — Member Information Management](https://developer.tuya.com/en/docs/app-development/member-information-management?id=Kaiy91tma26nh)
- [Tuya — Device Sharing](https://developer.tuya.com/en/docs/app-development/shareddevice?id=Ka6ki8l6pju4i)
- [Tuya — Device Control (Android)](https://developer.tuya.com/en/docs/app-development/andoird_device_control?id=Kaixh4pfm8f0y)
- [Tuya — Device Management](https://developer.tuya.com/en/docs/app-development/devicemanage?id=Ka6ki8r2rfiuu)
- [Tuya — Bluetooth Devices](https://developer.tuya.com/en/docs/app-development/ble?id=Ka5vcxzbglphd)
- [Tuya — Beacon Device Connection (TuyaOS)](https://developer.tuya.com/en/docs/iot-device-dev/Beacon-SDK?id=Kalgcuij4cdos)
- [Tuya — What is Bluetooth Beacon?](https://support.tuya.com/en/help/_detail/Kbic5mbai5ts3)
- [Tuya — Beacon bulb solution](https://solution.tuya.com/cms/solution/zm_dj_beacon_en)
- [Tuya — Scheduled Tasks](https://developer.tuya.com/en/docs/app-development/timer?id=Ka6ki8l85zpcu)
- [Tuya — Device Schedule (extension SDK)](https://developer.tuya.com/en/docs/app-development/extension-device-timer?id=Kcy2jpy6859p1)
- [Tuya — Android SDK API reference](https://tuya.github.io/tuya-home-android-sdk-api-reference/)
- Yeelight — *Yeelight WiFi Light Inter-Operation Specification* (PDF oficial, `yeelight.com/download/Yeelight_Inter-Operation_Spec.pdf`)
