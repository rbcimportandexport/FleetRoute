# Flutter Proguard Rules

# Flutter core
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep shared_preferences Pigeon native interop classes from being obfuscated or stripped by R8
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keepclassmembers class io.flutter.plugins.sharedpreferences.** {
    *;
}
-keep class * extends io.flutter.plugin.common.StandardMessageCodec { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**

# Play Core deferred components optional dependencies
-dontwarn com.google.android.play.core.**
