package cl.casacontrol.casacontrol.tuya

import android.app.Application
import android.content.Context
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Variante sin SDK de Tuya: permite compilar y usar Yeelight/Demo. */
object TuyaServiceFactory {
    fun onApplicationCreate(app: Application) = Unit

    fun create(context: Context): TuyaService = object : TuyaService {
        override fun handle(call: MethodCall, result: MethodChannel.Result) {
            when (call.method) {
                "initialize" -> result.success(mapOf("configured" to false))
                "isLoggedIn" -> result.success(false)
                else -> result.error(
                    "NOT_CONFIGURED",
                    "Este APK se compiló sin el SDK de Tuya (docs/TUYA_SETUP.md).",
                    null,
                )
            }
        }

        override fun setEventSink(sink: EventChannel.EventSink?) = Unit
        override fun dispose() = Unit
    }
}
