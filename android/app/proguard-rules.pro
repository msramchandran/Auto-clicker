# ── Flutter Core Rules ────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── AutoClicker App Code (Keep Accessibility Service & Managers 100% Intact) ───
-keep class com.example.autoclicker.** { *; }
-keepclassmembers class com.example.autoclicker.** { *; }

# ── libadb-android (Keep All ADB Connection & Protocol Classes) ───────────────
-keep class io.github.muntashirakon.adb.** { *; }
-dontwarn io.github.muntashirakon.adb.**

# ── Conscrypt TLS Engine (Fixes R8 Missing Class Warnings for KitKat/Legacy) ───
-keep class org.conscrypt.** { *; }
-dontwarn org.conscrypt.**
-dontwarn com.android.org.conscrypt.**
-dontwarn org.apache.harmony.xnet.provider.jsse.**

# ── BouncyCastle Cryptographic Provider (Keep SPAKE2 & Key Generation) ─────────
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# ── Google Play Core (Flutter Deferred Components) ───────────────────────────
-dontwarn com.google.android.play.core.**

