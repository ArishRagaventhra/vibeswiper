# Razorpay
-keepclassmembers class * {
    @com.razorpay.** *;
}
-keep class com.razorpay.** {*;}
-dontwarn com.razorpay.**

# Basic Android rules
-keepattributes Signature
-keepattributes *Annotation*
-keep class androidx.lifecycle.** { *; }
-keep class androidx.core.** { *; }

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep JavaScript interface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}