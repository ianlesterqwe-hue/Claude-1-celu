# Fase 3 — Configurar el SmartLife App SDK de Tuya

Sin estos pasos el APK se compila con la variante **stub**: Yeelight y el
Modo Demo funcionan, y la sección Tuya muestra "SDK no configurado".

## 1. Crear el proyecto en Tuya

1. Crear una cuenta en la plataforma de desarrolladores de Tuya
   (developer.tuya.com). Es independiente de la cuenta de Tuya Smart.
2. **App** → **SDK Development** → crear una app (SmartLife App SDK).
3. Nombre de paquete Android: `cl.casacontrol.casacontrol` (el de
   `android/app/build.gradle.kts`). Si se cambia, hay que regenerar el AAR.
4. Registrar el **SHA-256** del certificado de firma:
   - debug: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`
   - release: el SHA-256 del keystore de release (Fase 12).
5. Descargar el **security-algorithm AAR** y copiarlo a `android/app/libs/`.
   Está en `.gitignore`: no se versiona.
6. Anotar **AppKey**, **AppSecret** y la **versión del SDK** que indica la
   consola.
7. Revisar las condiciones de la licencia gratuita (Trial) vigentes.

## 2. Configurar el proyecto local

En `android/local.properties` (no versionado):

```properties
casacontrol.tuya.enabled=true
casacontrol.tuya.appKey=XXXXXXXX
casacontrol.tuya.appSecret=XXXXXXXX
casacontrol.tuya.sdkVersion=<versión indicada por Tuya>
```

`android/app/build.gradle.kts` entonces:

- compila `src/tuya/kotlin` en lugar de `src/tuyaStub/kotlin`;
- agrega `com.thingclips.smart:thingsmart:<versión>`, fastjson y el AAR;
- inyecta AppKey y AppSecret en el manifest (`THING_SMART_APPKEY` y
  `THING_SMART_SECRET`);
- limita las ABIs a ARM (el SDK trae librerías nativas sólo para ARM).

## 3. Primera compilación

`TuyaPlatformService.kt` se escribió con la documentación pública, pero
**todavía no se compiló contra el AAR real**. Las líneas marcadas con
`VERIFICAR` son las que probablemente haya que ajustar según la versión:

- getter de categoría en `DeviceBean`;
- `isBeacon` y detección del combo Wi-Fi+BLE;
- firma de `sendVerifyCodeWithUserName`;
- builder de timers (Fase 9).

Si Gradle reporta conflictos de dependencias, conviene revisar las reglas
de `packaging` o `exclude` que publique Tuya para esa versión del SDK.

## 4. Primer uso

1. Abrir CasaControl → Configuración → **Cuenta Tuya de CasaControl** →
   Crear cuenta. Es una cuenta nueva, **no** la de Tuya Smart.
2. Migrar cada dispositivo (ver `RESEARCH.md` §2.1): eliminarlo de Tuya
   Smart, ponerlo en modo emparejamiento y emparejarlo desde CasaControl.
   El flujo de pairing se agrega en las Fases 5 y 6.
3. Configuración → **Diagnóstico Tuya** → copiar PID, categoría,
   comunicación y Data Points a `DEVICE_INTEGRATION.md`.
