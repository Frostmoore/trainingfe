plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "it.riccardoronconi.training_companion"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // 🚨 Serve a `flutter_local_notifications` (C9.3), che usa le API di
        // data e ora di Java 8 anche su Android vecchi. Senza, la build
        // fallisce con «requires core library desugaring to be enabled» e il
        // messaggio non dice a cosa serve: l'ha portato dentro il timer di
        // riposo del player.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "it.riccardoronconi.training_companion"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        /*
         * 🚨 minSdk 26 (Android 8.0) fissato a mano — S3.3.
         *
         * Lo pretende il pacchetto `health`, cioe' Health Connect. Non e' una
         * scelta nostra e non si puo' aggirare: sotto Android 8 quelle API non
         * esistono proprio.
         *
         * ⚠️ **Chi resta fuori**: i telefoni con Android 7 o precedente, usciti
         * prima del 2017. E' una quota di mercato ormai sotto l'1%, e in
         * palestra un telefono di nove anni fa non regge nemmeno il player.
         *
         * ⚠️ Va tenuto **allineato con `flutter.minSdkVersion`**: se un domani
         * Flutter alzasse il suo default sopra 26, questa riga lo abbasserebbe
         * in silenzio. Per questo c'e' il `maxOf`, e non un 26 secco.
         */
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // ⚠️ La versione la impone il plugin delle notifiche: una più vecchia fa
    // fallire la build con un errore che parla di classi mancanti, non di
    // versioni sbagliate.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
