import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clave de subida a Google Play (Play App Signing: Google guarda la de
// firma). Fuera del repo, en ~/keys/lat41lab/terrazeo/key.properties; también
// vale android/key.properties (excluido en .gitignore). Ver PUBLICAR.md.
val keystoreProperties = Properties().apply {
    val f = listOf(
        File(System.getProperty("user.home"), "keys/lat41lab/terrazeo/key.properties"),
        rootProject.file("key.properties"),
    ).firstOrNull { it.exists() }
    if (f != null) f.inputStream().use { load(it) }
}

android {
    namespace = "com.lat41lab.terrazeo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lat41lab.terrazeo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!keystoreProperties.isEmpty) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Con la clave de subida firma con ella; sin ella, con la de debug
            // (solo para probar con `flutter run --release`: el AAB para Google
            // Play no se deja generar así, ver abajo).
            signingConfig = if (keystoreProperties.isEmpty) {
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("release")
            }
        }
    }
}

// Un AAB firmado con la clave de debug lo rechaza Google Play: mejor fallar.
gradle.taskGraph.whenReady {
    if (keystoreProperties.isEmpty && allTasks.any { it.name == "bundleRelease" }) {
        throw GradleException(
            "Falta la clave de subida (~/keys/lat41lab/terrazeo/key.properties): " +
                "no se genera un AAB de release firmado con la clave de debug.",
        )
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
