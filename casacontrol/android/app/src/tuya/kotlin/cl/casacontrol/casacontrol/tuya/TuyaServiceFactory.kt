package cl.casacontrol.casacontrol.tuya

import android.app.Application
import android.content.Context
import com.thingclips.smart.home.sdk.ThingHomeSdk

/** Variante con el SmartLife App SDK oficial. */
object TuyaServiceFactory {
    fun onApplicationCreate(app: Application) {
        // AppKey/AppSecret se leen del AndroidManifest (THING_SMART_APPKEY /
        // THING_SMART_SECRET), inyectados desde local.properties.
        ThingHomeSdk.init(app)
        ThingHomeSdk.setDebugMode(BuildConfigHelper.isDebug(app))
    }

    fun create(context: Context): TuyaService = TuyaPlatformService(context)
}

private object BuildConfigHelper {
    fun isDebug(context: Context): Boolean =
        (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
}
