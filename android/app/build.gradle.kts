import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Release signing: android/key.properties (gitignored) holds the upload
// keystore path + passwords. Release tasks fail when it is absent: a bundle
// called "release" but signed by Android Debug is not publishable and is too
// easy to upload by mistake.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val requiredSigningProperties = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
)
if (releaseTaskRequested) {
    if (!keystorePropertiesFile.exists()) {
        throw GradleException(
            "Release signing is not configured. Copy android/key.properties.example " +
                "to android/key.properties and point it at the FoxyCo upload keystore."
        )
    }
    val missing = requiredSigningProperties.filter {
        keystoreProperties.getProperty(it).isNullOrBlank()
    }
    if (missing.isNotEmpty()) {
        throw GradleException(
            "Missing release-signing values in android/key.properties: ${missing.joinToString()}"
        )
    }
    val configuredStore = file(keystoreProperties.getProperty("storeFile"))
    if (!configuredStore.isFile) {
        throw GradleException(
            "Release keystore does not exist: ${configuredStore.absolutePath}"
        )
    }
}

android {
    namespace = "com.foxyco.foxyco"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // FoxyCo application ID — LOCKED 2026-07-20 for Play; never change post-publish.
        applicationId = "com.foxyco.app"
        // minSdk 26: required for TYPE_APPLICATION_OVERLAY (the pill/bubble overlay, M2). See docs/ARCHITECTURE.md.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
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
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            // R8: shrink + obfuscate. Keep rules cover the two vendored
            // plugins (accessed reflectively by the Flutter engine).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
