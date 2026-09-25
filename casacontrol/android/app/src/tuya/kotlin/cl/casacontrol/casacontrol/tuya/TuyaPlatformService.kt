package cl.casacontrol.casacontrol.tuya

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.alibaba.fastjson.JSONObject
import com.thingclips.smart.android.user.api.ILoginCallback
import com.thingclips.smart.android.user.api.ILogoutCallback
import com.thingclips.smart.android.user.api.IRegisterCallback
import com.thingclips.smart.android.user.bean.User
import com.thingclips.smart.home.sdk.ThingHomeSdk
import com.thingclips.smart.home.sdk.bean.HomeBean
import com.thingclips.smart.home.sdk.bean.InviteMessageBean
import com.thingclips.smart.home.sdk.bean.MemberBean
import com.thingclips.smart.home.sdk.callback.IThingGetHomeListCallback
import com.thingclips.smart.home.sdk.callback.IThingGetMemberListCallback
import com.thingclips.smart.home.sdk.callback.IThingHomeResultCallback
import com.thingclips.smart.sdk.api.IDevListener
import com.thingclips.smart.sdk.api.IResultCallback
import com.thingclips.smart.sdk.api.IThingDataCallback
import com.thingclips.smart.sdk.api.IThingDevice
import com.thingclips.smart.sdk.bean.DeviceBean
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Envoltura del SmartLife App SDK de Tuya expuesta a Flutter.
 *
 * API (espejo de lib/adapters/tuya/tuya_platform.dart):
 *   initialize, isLoggedIn, sendEmailCode, registerWithEmail, login, logout,
 *   getHomes, createHome, getDevices, connectDevice, publishDataPoints,
 *   (EventChannel) subscribeDeviceState, createSchedule, getSchedules,
 *   removeSchedule, shareHome, joinHome, getMembers.
 *
 * ESTADO: escrito contra la documentación pública del SDK, SIN compilar
 * todavía contra el AAR real (requiere AppKey, AppSecret y el
 * security-algorithm AAR de un proyecto Tuya). Los puntos marcados con
 * "VERIFICAR" deben confirmarse en la Fase 3 con la versión del SDK usada.
 */
class TuyaPlatformService(private val context: Context) : TuyaService {
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private val devices = mutableMapOf<String, IThingDevice>()

    override fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initialize" -> result.success(
                    mapOf("configured" to true, "sdkVersion" to sdkVersion()),
                )
                "isLoggedIn" -> result.success(ThingHomeSdk.getUserInstance().isLogin)
                "sendEmailCode" -> sendEmailCode(call, result)
                "registerWithEmail" -> registerWithEmail(call, result)
                "login" -> login(call, result)
                "logout" -> logout(result)
                "getHomes" -> getHomes(result)
                "createHome" -> createHome(call, result)
                "getDevices" -> getDevices(call, result)
                "connectDevice" -> connectDevice(call, result)
                "publishDataPoints" -> publishDataPoints(call, result)
                "createSchedule" -> createSchedule(call, result)
                "getSchedules" -> getSchedules(call, result)
                "removeSchedule" -> removeSchedule(call, result)
                "shareHome" -> shareHome(call, result)
                "joinHome" -> joinHome(call, result)
                "getMembers" -> getMembers(call, result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("TUYA_EXCEPTION", e.message, null)
        }
    }

    // ---------------------------------------------------------------- cuenta

    private fun sendEmailCode(call: MethodCall, result: MethodChannel.Result) {
        // type 1 = registro. VERIFICAR firma en la versión del SDK.
        ThingHomeSdk.getUserInstance().sendVerifyCodeWithUserName(
            call.argument<String>("email"),
            "",
            call.argument<String>("countryCode"),
            1,
            resultCallback(result),
        )
    }

    private fun registerWithEmail(call: MethodCall, result: MethodChannel.Result) {
        ThingHomeSdk.getUserInstance().registerAccountWithEmail(
            call.argument<String>("countryCode"),
            call.argument<String>("email"),
            call.argument<String>("password"),
            call.argument<String>("code"),
            object : IRegisterCallback {
                override fun onSuccess(user: User?) = reply { result.success(null) }
                override fun onError(code: String?, error: String?) =
                    reply { result.error(code ?: "REGISTER", error, null) }
            },
        )
    }

    private fun login(call: MethodCall, result: MethodChannel.Result) {
        ThingHomeSdk.getUserInstance().loginWithEmail(
            call.argument<String>("countryCode"),
            call.argument<String>("email"),
            call.argument<String>("password"),
            object : ILoginCallback {
                // No se devuelve nada del User: contiene tokens de sesión.
                override fun onSuccess(user: User?) = reply { result.success(null) }
                override fun onError(code: String?, error: String?) =
                    reply { result.error(code ?: "LOGIN", error, null) }
            },
        )
    }

    private fun logout(result: MethodChannel.Result) {
        ThingHomeSdk.getUserInstance().logout(object : ILogoutCallback {
            override fun onSuccess() = reply { result.success(null) }
            override fun onError(code: String?, error: String?) =
                reply { result.error(code ?: "LOGOUT", error, null) }
        })
    }

    // ----------------------------------------------------------------- homes

    private fun getHomes(result: MethodChannel.Result) {
        ThingHomeSdk.getHomeManagerInstance().queryHomeList(object : IThingGetHomeListCallback {
            override fun onSuccess(homes: MutableList<HomeBean>?) = reply {
                result.success(
                    homes.orEmpty().map {
                        mapOf(
                            "homeId" to it.homeId,
                            "name" to it.name,
                            "admin" to it.isAdmin,
                        )
                    },
                )
            }

            override fun onError(code: String?, error: String?) =
                reply { result.error(code ?: "HOMES", error, null) }
        })
    }

    private fun createHome(call: MethodCall, result: MethodChannel.Result) {
        ThingHomeSdk.getHomeManagerInstance().createHome(
            call.argument<String>("name"),
            0.0,
            0.0,
            "",
            listOf("Salón"),
            object : IThingHomeResultCallback {
                override fun onSuccess(bean: HomeBean?) = reply { result.success(bean?.homeId) }
                override fun onError(code: String?, error: String?) =
                    reply { result.error(code ?: "CREATE_HOME", error, null) }
            },
        )
    }

    private fun getDevices(call: MethodCall, result: MethodChannel.Result) {
        val homeId = (call.argument<Number>("homeId") ?: 0).toLong()
        ThingHomeSdk.newHomeInstance(homeId).getHomeDetail(object : IThingHomeResultCallback {
            override fun onSuccess(bean: HomeBean?) {
                val roomOf = mutableMapOf<String, String>()
                bean?.rooms?.forEach { room ->
                    room.deviceList?.forEach { d -> roomOf[d.devId] = room.name }
                }
                val list = bean?.deviceList.orEmpty().map { d ->
                    listen(d.devId)
                    deviceToMap(d, roomOf[d.devId])
                }
                reply { result.success(list) }
            }

            override fun onError(code: String?, error: String?) =
                reply { result.error(code ?: "HOME_DETAIL", error, null) }
        })
    }

    /**
     * Serializa un DeviceBean SIN secretos: se omiten localKey, secKey,
     * uuid, mac, tokens, etc. Sólo metadatos, esquema y valores de DP.
     */
    private fun deviceToMap(d: DeviceBean, roomName: String?): Map<String, Any?> {
        val schema = ThingHomeSdk.getDataInstance().getSchema(d.devId).orEmpty()
        return mapOf(
            "devId" to d.devId,
            "name" to d.name,
            "productId" to d.productId,
            // VERIFICAR: nombre del getter de categoría según versión del SDK.
            "category" to d.deviceCategory,
            "productName" to d.productBean?.name,
            "online" to d.isOnline,
            "localOnline" to d.isLocalOnline,
            "communication" to communicationOf(d),
            "roomName" to roomName,
            "dps" to d.dps.orEmpty().mapValues { it.value },
            "schema" to schema.values.map {
                mapOf(
                    "id" to it.id,
                    "code" to it.code,
                    "name" to it.name,
                    "mode" to it.mode,
                    "type" to it.type,
                    "schemaType" to it.schemaType,
                    "property" to it.property,
                )
            },
        )
    }

    /**
     * Tipo de comunicación. Es la respuesta a "¿qué es Beacon RGBCW 2?":
     * se decide con lo que informa el SDK, no por el nombre.
     * VERIFICAR (Fase 4): métodos disponibles en DeviceBean de la versión
     * usada (isBeacon puede no existir en versiones antiguas).
     */
    private fun communicationOf(d: DeviceBean): String = when {
        d.isBeacon -> "beacon"
        d.isSigMesh -> "sigmesh"
        d.isBlueMesh -> "mesh"
        d.isBluetooth && d.hasWifi() -> "combo"
        d.isBluetooth -> "ble"
        else -> "wifi"
    }

    private fun DeviceBean.hasWifi(): Boolean =
        // Wi-Fi + BLE combo: el SDK los marca con capacidad Wi-Fi además de BLE.
        // VERIFICAR con ProductBean.capability en la Fase 4.
        (productBean?.capability ?: 0) and 0x1 != 0

    // --------------------------------------------------------------- control

    private fun listen(devId: String) {
        if (devices.containsKey(devId)) return
        val device = ThingHomeSdk.newDeviceInstance(devId)
        device.registerDevListener(object : IDevListener {
            override fun onDpUpdate(devId: String, dpStr: String) {
                val dps = JSONObject.parseObject(dpStr)?.innerMap.orEmpty()
                emit(mapOf("type" to "dpUpdate", "devId" to devId, "dps" to dps))
            }

            override fun onRemoved(devId: String) =
                emit(mapOf("type" to "removed", "devId" to devId))

            override fun onStatusChanged(devId: String, online: Boolean) =
                emit(mapOf("type" to "online", "devId" to devId, "online" to online))

            override fun onNetworkStatusChanged(devId: String, status: Boolean) = Unit

            override fun onDevInfoUpdate(devId: String) =
                emit(mapOf("type" to "infoUpdate", "devId" to devId))
        })
        devices[devId] = device
    }

    private fun connectDevice(call: MethodCall, result: MethodChannel.Result) {
        // Para Wi-Fi no hace falta. Para Beacon/Mesh el SDK gestiona el
        // canal al publicar DPs. La conexión explícita de BLE punto a punto
        // se implementará en la Fase 6, cuando se conozca el tipo real del
        // Beacon RGBCW 2 (no se escriben características GATT a mano).
        result.success(null)
    }

    private fun publishDataPoints(call: MethodCall, result: MethodChannel.Result) {
        val devId = call.argument<String>("devId")!!
        val dps = call.argument<Map<String, Any>>("dps")!!
        listen(devId)
        devices[devId]!!.publishDps(JSONObject(dps).toJSONString(), resultCallback(result))
    }

    // -------------------------------------------------------------- horarios

    private fun createSchedule(call: MethodCall, result: MethodChannel.Result) {
        // VERIFICAR (Fase 9): builder de timers de la versión del SDK
        // (ThingTimerBuilder vs. DeviceTimerManager de extensión).
        result.error("NOT_IMPLEMENTED", "Horarios: Fase 9", null)
    }

    private fun getSchedules(call: MethodCall, result: MethodChannel.Result) =
        result.error("NOT_IMPLEMENTED", "Horarios: Fase 9", null)

    private fun removeSchedule(call: MethodCall, result: MethodChannel.Result) =
        result.error("NOT_IMPLEMENTED", "Horarios: Fase 9", null)

    // ------------------------------------------------------ compartir (Home)

    private fun shareHome(call: MethodCall, result: MethodChannel.Result) {
        val homeId = (call.argument<Number>("homeId") ?: 0).toLong()
        ThingHomeSdk.getMemberInstance().getInvitationMessage(
            homeId,
            object : IThingDataCallback<InviteMessageBean> {
                override fun onSuccess(bean: InviteMessageBean?) =
                    reply { result.success(bean?.invitationCode) }

                override fun onError(code: String?, error: String?) =
                    reply { result.error(code ?: "INVITE", error, null) }
            },
        )
    }

    private fun joinHome(call: MethodCall, result: MethodChannel.Result) {
        ThingHomeSdk.getHomeManagerInstance().joinHomeByInviteCode(
            call.argument<String>("code"),
            resultCallback(result),
        )
    }

    private fun getMembers(call: MethodCall, result: MethodChannel.Result) {
        val homeId = (call.argument<Number>("homeId") ?: 0).toLong()
        ThingHomeSdk.getMemberInstance().queryMemberList(
            homeId,
            object : IThingGetMemberListCallback {
                override fun onSuccess(members: MutableList<MemberBean>?) = reply {
                    result.success(
                        members.orEmpty().map {
                            mapOf("name" to it.nickName, "role" to it.role, "admin" to it.isAdmin)
                        },
                    )
                }

                override fun onError(code: String?, error: String?) =
                    reply { result.error(code ?: "MEMBERS", error, null) }
            },
        )
    }

    // ----------------------------------------------------------------- util

    private fun sdkVersion(): String? = try {
        com.thingclips.smart.home.sdk.BuildConfig::class.java
            .getField("VERSION_NAME").get(null) as? String
    } catch (_: Exception) {
        null
    }

    private fun resultCallback(result: MethodChannel.Result) = object : IResultCallback {
        override fun onSuccess() = reply { result.success(null) }
        override fun onError(code: String?, error: String?) =
            reply { result.error(code ?: "TUYA", error, null) }
    }

    private fun reply(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else main.post(block)
    }

    private fun emit(event: Map<String, Any?>) = reply { sink?.success(event) }

    override fun setEventSink(sink: EventChannel.EventSink?) {
        this.sink = sink
    }

    override fun dispose() {
        devices.values.forEach { it.unRegisterDevListener(); it.onDestroy() }
        devices.clear()
        sink = null
    }
}
