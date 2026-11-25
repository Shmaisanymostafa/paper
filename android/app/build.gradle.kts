import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Keep release credentials out of source control. Ordinary release builds must
// have a configured identity; unsigned artifacts require an explicit audit opt-in.
val releaseSigningFile = rootProject.file("key.properties")
val releaseSigningConfigured = releaseSigningFile.isFile
val allowUnsignedRelease =
    providers.gradleProperty("cave.allowUnsignedRelease").orNull == "true"
val releaseSigning = Properties()
if (releaseSigningConfigured) {
    releaseSigningFile.inputStream().use { releaseSigning.load(it) }
    for (name in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
        require(!releaseSigning.getProperty(name).isNullOrBlank()) {
            "android/key.properties is missing required signing property: $name"
        }
    }
    require(rootProject.file(releaseSigning.getProperty("storeFile")).isFile) {
        "Release keystore does not exist; check storeFile in android/key.properties."
    }
}

android {
    namespace = "technology.cave.paper"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "technology.cave.paper"
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
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = rootProject.file(releaseSigning.getProperty("storeFile"))
                storePassword = releaseSigning.getProperty("storePassword")
                keyAlias = releaseSigning.getProperty("keyAlias")
                keyPassword = releaseSigning.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseSigningConfigured) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

tasks.configureEach {
    if (name == "preReleaseBuild") {
        // Capture validated configuration, rather than rechecking file existence
        // after Gradle has already selected the signing configuration.
        val signingConfigured = releaseSigningConfigured
        val unsignedAuditRequested = allowUnsignedRelease
        doFirst {
            if (!signingConfigured && !unsignedAuditRequested) {
                throw GradleException(
                    "Android release signing is not configured. Configure the ignored " +
                        "android/key.properties before building an installable APK/AAB. " +
                        "For non-installable audit artifacts only, explicitly pass " +
                        "-Pcave.allowUnsignedRelease=true."
                )
            }
            if (!signingConfigured) {
                logger.warn(
                    "UNSIGNED AUDIT ONLY: this Android artifact cannot be installed " +
                        "or distributed as an installable release."
                )
            }
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
