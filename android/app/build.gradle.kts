plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties") // reads android/key.properties
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val hasReleaseSigningConfig =
    listOf("keyAlias", "keyPassword", "storeFile", "storePassword").all { key ->
        !keystoreProperties.getProperty(key).isNullOrBlank()
    }

fun isReleaseTaskRequested(): Boolean {
    return gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
}

android {
    namespace = "com.hopper.hopper"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.hopper.hopper"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        if (hasReleaseSigningConfig) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            if (hasReleaseSigningConfig) {
                signingConfig = signingConfigs.getByName("release")
            } else if (isReleaseTaskRequested()) {
                throw GradleException(
                    "Missing Android release signing config. Create android/key.properties " +
                        "with keyAlias/keyPassword/storeFile/storePassword (do not commit it).",
                )
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro"),
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")

    // Use Firebase BOM to manage versions
    implementation(platform("com.google.firebase:firebase-bom:33.13.0"))

    // Firebase Messaging (exclude IID only if you get duplicate class issues)
    implementation("com.google.firebase:firebase-messaging") {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }

    // NOTE: Don't add ML Kit Text Recognition unless it's actually used.
    // It bundles native OCR pipeline libraries that can trip Play's
    // "16 KB memory page sizes" checks if an incompatible version is used.
}
