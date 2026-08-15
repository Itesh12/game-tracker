package com.example.game_tracker.domain.model

sealed class PlatformRestriction(val code: String, val message: String) {
    object MediaProjectionConsentRequired : PlatformRestriction("RESTRICTION_MEDIAPROJECTION_CONSENT_REQUIRED", "User screen capture consent token expired or missing")
    object CameraPermissionMissing : PlatformRestriction("RESTRICTION_CAMERA_PERMISSION_MISSING", "Camera permission (android.permission.CAMERA) denied")
    object BackgroundActivityLaunchBlocked : PlatformRestriction("RESTRICTION_BAL_BLOCKED", "Background Activity Launch blocked by Android 12+ BAL rules")
    object ForceStopped : PlatformRestriction("RESTRICTION_FORCE_STOPPED", "Application in FLAG_STOPPED state (Force-stopped by user)")
    object BatteryOptimizationBlocked : PlatformRestriction("RESTRICTION_BATTERY_OPTIMIZATION", "Execution deferred due to active Doze mode or Battery Saver")
    object ForegroundServiceStartRestricted : PlatformRestriction("RESTRICTION_FGS_START_RESTRICTED", "Foreground Service start restricted by Android 14+ FGS rules")
}
