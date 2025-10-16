# -------------------------
# ML Kit Text Recognition
# -------------------------
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }
-dontwarn com.google.mlkit.vision.text.**

# Uncomment if using language-specific text recognition
#-keep class com.google.mlkit.vision.text.chinese.** { *; }
#-keep class com.google.mlkit.vision.text.devanagari.** { *; }
#-keep class com.google.mlkit.vision.text.japanese.** { *; }
#-keep class com.google.mlkit.vision.text.korean.** { *; }

# -------------------------
# Stripe SDK Keep Rules
# -------------------------
-keep class com.stripe.android.pushProvisioning.** { *; }
-keep class com.stripe.android.** { *; }
-dontwarn com.stripe.android.**
