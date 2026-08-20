# ── Flutter ──────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ── Firebase ─────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.firestore.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.crashlytics.** { *; }

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }

# ── ZEGOCLOUD ─────────────────────────────────────────────────────
-keep class im.zego.** { *; }
-dontwarn im.zego.**
-keep class com.zego.** { *; }
-dontwarn com.zego.**

# ── Kotlin ────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ── OkHttp ────────────────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# ── Gson / JSON ───────────────────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# ── Play Core ─────────────────────────────────────────────────────
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ── Record / Audio ────────────────────────────────────────────────
-keep class com.github.llfbandit.record.** { *; }
-dontwarn com.github.llfbandit.record.**

# ── AudioPlayers ─────────────────────────────────────────────────
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# ── General ───────────────────────────────────────────────────────
-keepattributes InnerClasses
-keep class **.R$* { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
