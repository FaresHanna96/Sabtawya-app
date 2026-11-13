import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

android {
    namespace = "com.sabtawya.sabtawya"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Needed by ota_update (in-app update).
        isCoreLibraryDesugaringEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String?
            keyPassword = keyProperties["keyPassword"] as String?
            storeFile = keyProperties["storeFile"]?.let { file(it as String) }
            storePassword = keyProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "com.sabtawya.sabtawya"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // The dev/test build (build_dev.ps1 sets SABT_DEV=1) installs next to the
        // real app: its own package name and label.
        if (System.getenv("SABT_DEV") == "1") {
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "سبتاوية DEV"
        } else {
            manifestPlaceholders["appLabel"] = "خدمة 3:6 ابتدائي السبت"
        }
    }

    buildTypes {
        release {
            val keystorePath = keyProperties["storeFile"]?.let { rootProject.file(it as String) }
            signingConfig = if (keyPropertiesFile.exists() && keystorePath?.exists() == true)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
