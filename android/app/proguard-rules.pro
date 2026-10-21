
-keep class com.follow.clash.models.** { *; }

-keep class com.follow.clash.service.models.** { *; }

# Barcode scanning (play-services-mlkit) references the firebase-components
# registry types, but Vyrax links no Firebase services; the reference paths
# are never exercised at runtime, so R8 may drop them silently.
-dontwarn com.google.firebase.components.**
