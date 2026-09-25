import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- Tuya SmartLife App SDK (opcional) -----------------------------------
// Se activa en android/local.properties (archivo NO versionado):
//   casacontrol.tuya.enabled=true
//   casacontrol.tuya.appKey=...
//   casacontrol.tuya.appSecret=...
//   casacontrol.tuya.sdkVersion=<versión indicada en la consola Tuya>
// y copiando el security-algorithm AAR del proyecto Tuya a android/app/libs/.
// Sin esto se compila la variante stub (Yeelight + Demo funcionan igual).
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val tuyaEnabled = localProps.getProperty("casacontrol.tuya.enabled") == "true"
val tuyaSdkVersion: String? = localProps.getProperty("casacontrol.tuya.sdkVersion")
if (tuyaEnabled) {
    require(!tuyaSdkVersion.isNullOrBlank()) {
        "casacontrol.tuya.sdkVersion no definido en local.properties (ver docs/TUYA_SETUP.md)"
    }
}

android {
    namespace = "cl.casacontrol.casacontrol"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "cl.casacontrol.casacontrol"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["tuyaAppKey"] =
            if (tuyaEnabled) localProps.getProperty("casacontrol.tuya.appKey", "") else ""
        manifestPlaceholders["tuyaAppSecret"] =
            if (tuyaEnabled) localProps.getProperty("casacontrol.tuya.appSecret", "") else ""
        if (tuyaEnabled) {
            // El SDK de Tuya distribuye librerías nativas sólo para ARM.
            ndk { abiFilters += listOf("armeabi-v7a", "arm64-v8a") }
        }
    }

    sourceSets {
        getByName("main") {
            java.srcDir(if (tuyaEnabled) "src/tuya/kotlin" else "src/tuyaStub/kotlin")
        }
    }

    packaging {
        jniLibs {
            pickFirsts += listOf("lib/*/libc++_shared.so")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    if (tuyaEnabled) {
        implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar"))))
        implementation("com.alibaba:fastjson:1.1.67.android")
        implementation("com.thingclips.smart:thingsmart:$tuyaSdkVersion")
    }
}
