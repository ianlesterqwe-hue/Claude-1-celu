package cl.casacontrol.casacontrol.tuya

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Contrato entre el canal Flutter "casacontrol/tuya" y la implementación
 * nativa. Hay dos implementaciones, elegidas en tiempo de compilación:
 *
 *  - src/tuya:     TuyaPlatformService, envuelve el SmartLife App SDK.
 *  - src/tuyaStub: responde configured=false (APK sin credenciales Tuya).
 *
 * Regla de seguridad: nunca se envían a Dart local keys, tokens de sesión
 * ni secretos del SDK.
 */
interface TuyaService {
    fun handle(call: MethodCall, result: MethodChannel.Result)
    fun setEventSink(sink: EventChannel.EventSink?)
    fun dispose()
}
