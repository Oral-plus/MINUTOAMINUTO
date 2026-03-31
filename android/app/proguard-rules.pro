# Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.**

# App native Kotlin classes
-keep class com.minutoaminuto.minuto_a_minuto.** { *; }

# Flutter foreground task
-keep class com.pravera.flutter_foreground_task.** { *; }
-dontwarn com.pravera.flutter_foreground_task.**

# Geolocator
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# Permission handler
-keep class com.baseflow.permissionhandler.** { *; }

# Google Maps / Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.maps.** { *; }

# WorkManager (androidx.work)
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# Flutter local notifications
-keep class com.dexterous.** { *; }

# just_audio / audio
-keep class com.ryanheise.** { *; }
-dontwarn com.ryanheise.**

# flutter_overlay_window
-keep class net.overlaywindow.** { *; }
-dontwarn net.overlaywindow.**

# Serialize/deserialize (Gson, JSON)
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# Kotlin metadata
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontnote kotlin.**

# General Android
-keep class androidx.** { *; }
-dontwarn androidx.**
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.accessibilityservice.AccessibilityService
