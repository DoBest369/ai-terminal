plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.termind.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.termind.app"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.14"
    }
    packaging {
        resources.excludes += listOf(
            "/META-INF/{AL2.0,LGPL2.1}",
            "META-INF/*.SF", "META-INF/*.DSA", "META-INF/*.RSA",
            "META-INF/versions/9/OSGI-INF/MANIFEST.MF",
            "META-INF/BC1024KE.RSA", "META-INF/BC2048KE.RSA",
            "META-INF/INDEX.LIST", "META-INF/DEPENDENCIES"
        )
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.activity:activity-compose:1.8.2")
    implementation(platform("androidx.compose:compose-bom:2024.02.02"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    // SSH（纯 Java，适合 Android）
    implementation("com.hierynomus:sshj:0.38.0")
    implementation("org.slf4j:slf4j-nop:2.0.9")
    // AI HTTP
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    // API Key 加密存储（对齐 apple Keychain）
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    // 定时后台巡检（主动运维）
    implementation("androidx.work:work-runtime-ktx:2.9.0")
}
