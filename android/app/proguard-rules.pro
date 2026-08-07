# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Keep Domain Command DTOs and Data Models for IPC Serialization
-keep class com.example.game_tracker.domain.** { *; }
-keep class com.example.game_tracker.application.** { *; }
-keep class com.example.game_tracker.infrastructure.** { *; }

# Room Database ProGuard Rules
-keep class * extends androidx.room.RoomDatabase
-dontwarn androidx.room.paging.**

# WorkManager ProGuard Rules
-keep class * extends androidx.work.ListenableWorker { *; }

# WebRTC & MediaProjection ProGuard Rules
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
