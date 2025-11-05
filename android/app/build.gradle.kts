plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
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

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
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

    // ML Kit Text Recognition
    implementation("com.google.mlkit:text-recognition:16.0.0")
}




//plugins {
//    id("com.android.application")
//    id("kotlin-android")
//    id("com.google.gms.google-services")
//    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
//    id("dev.flutter.flutter-gradle-plugin")
//}
//
//android {
//    namespace = "com.hopper.hopper"
//    compileSdk = flutter.compileSdkVersion
////    ndkVersion = flutter.ndkVersion
//    ndkVersion = "27.0.12077973"
//
//
//    compileOptions {
//        sourceCompatibility = JavaVersion.VERSION_11
//        targetCompatibility = JavaVersion.VERSION_11
//        isCoreLibraryDesugaringEnabled = true
//    }
//
//
//    kotlinOptions {
//        jvmTarget = JavaVersion.VERSION_11.toString()
//    }
//
//    defaultConfig {
//        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
//        applicationId = "com.hopper.hopper"
//        // You can update the following values to match your application needs.
//        // For more information, see: https://flutter.dev/to/review-gradle-config.
//        minSdk = 24
//        targetSdk = flutter.targetSdkVersion
//        versionCode = flutter.versionCode
//        versionName = flutter.versionName
//    }
//
//    buildTypes {
//        release {
//            isMinifyEnabled = true
//            isShrinkResources = true
//            // TODO: Add your own signing config for the release build.
//            // Signing with the debug keys for now, so `flutter run --release` works.
//            signingConfig = signingConfigs.getByName("debug")
//            proguardFiles(
//                getDefaultProguardFile("proguard-android-optimize.txt"),
//                file("proguard-rules.pro") // Ensure this file exists
//            )
//        }
//    }
//    configurations.all {
//        resolutionStrategy.eachDependency {
//            if (requested.group == "com.google.firebase" && requested.name == "firebase-iid") {
//                useTarget("com.google.firebase:firebase-iid:999.0.0") // effectively removes IID
//            }
//        }
//    }
//
//}
//
//flutter {
//    source = "../.."
//}
//dependencies {
//    implementation("com.google.firebase:firebase-messaging") {
//        exclude(group = "com.google.firebase", module = "firebase-iid")
//    }
//
//    // Example: ML Kit
//    implementation("com.google.mlkit:text-recognition:16.0.0") {
//        exclude(group = "com.google.firebase", module = "firebase-iid")
//    }
//}
//
