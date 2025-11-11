# Preserve Firebase, Firestore, and SharedPreferences classes
-keep class com.google.firebase.** { *; }
-keep class com.google.firestore.** { *; }
-keep class com.google.protobuf.** { *; }
-keep class androidx.datastore.preferences.protobuf.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Prevent obfuscation of AwesomeNotifications
-keep class me.carda.awesome_notifications.** { *; }

# Keep Gson & Guava reflection-based classes
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class com.google.common.reflect.TypeToken { *; }
-keep class * extends com.google.common.reflect.TypeToken { *; }

# Keep WorkManager for background notifications
-keep class androidx.work.** { *; }

# Preserve timezone classes
-keep class java.util.TimeZone { *; }

# Preserve Play Core classes used for SplitCompat and SplitInstall
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Suppress warnings for missing classes
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task


# Prevent removing reflection-based annotations
-keepattributes *Annotation*
-keep class * {
    @Keep
}

# Keep Firebase and Google services classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.gson.** { *; }

# Keep plugin classes
-keep class io.flutter.plugins.** { *; }

# Keep Dio, its full networking stack (OkHttp, Okio), and its dependencies
-keep class io.flutter.plugins.dio.** { *; }
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }
-keep interface okio.** { *; }

# Required by OkHttp for modern TLS/SSL (This is likely the fix)
-keep class org.conscrypt.** { *; }

# Keep all GSON classes
-keep class com.google.gson.** { *; }

# Keep Dio, its full networking stack (OkHttp, Okio), and its dependencies
-keep class io.flutter.plugins.dio.** { *; }
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }
-keep interface okio.** { *; }
-keep class org.conscrypt.** { *; }

# Keep Kotlin coroutines, which many modern libraries (Firebase, Dio, etc.) depend on
-keep class kotlinx.coroutines.** { *; }
-keep interface kotlinx.coroutines.** { *; }
-keep class kotlin.coroutines.** { *; }
-keep interface kotlin.coroutines.** { *; }
-keep class kotlin.Unit { *; }
-keep class kotlin.jvm.functions.** { *; }

# Also keep the audio plugin code, just in case
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.simform.audio_waveforms.** { *; }