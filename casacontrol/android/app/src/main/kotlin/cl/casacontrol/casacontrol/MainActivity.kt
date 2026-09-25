package cl.casacontrol.casacontrol

import android.content.Context
import android.net.wifi.WifiManager
import cl.casacontrol.casacontrol.tuya.TuyaService
import cl.casacontrol.casacontrol.tuya.TuyaServiceFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var tuya: TuyaService? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Android descarta el tráfico multicast salvo que se tome un
        // MulticastLock. Lo necesitan los anuncios NOTIFY de Yeelight.
        acquireMulticastLock()

        val service = TuyaServiceFactory.create(applicationContext)
        tuya = service
        MethodChannel(messenger, "casacontrol/tuya").setMethodCallHandler { call, result ->
            service.handle(call, result)
        }
        EventChannel(messenger, "casacontrol/tuya/events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    service.setEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    service.setEventSink(null)
                }
            },
        )
    }

    private fun acquireMulticastLock() {
        if (multicastLock?.isHeld == true) return
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        multicastLock = wifi.createMulticastLock("casacontrol-yeelight").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    override fun onDestroy() {
        multicastLock?.let { if (it.isHeld) it.release() }
        multicastLock = null
        tuya?.dispose()
        tuya = null
        super.onDestroy()
    }
}
