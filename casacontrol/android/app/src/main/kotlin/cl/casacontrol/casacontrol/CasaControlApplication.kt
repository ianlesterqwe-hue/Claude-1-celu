package cl.casacontrol.casacontrol

import android.app.Application
import cl.casacontrol.casacontrol.tuya.TuyaServiceFactory

class CasaControlApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Inicializa el SDK de Tuya sólo si este APK se compiló con él.
        TuyaServiceFactory.onApplicationCreate(this)
    }
}
