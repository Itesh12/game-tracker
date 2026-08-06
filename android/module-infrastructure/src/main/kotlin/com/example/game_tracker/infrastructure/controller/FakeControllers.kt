package com.example.game_tracker.infrastructure.controller

import com.example.game_tracker.domain.controller.MediaProjectionController
import com.example.game_tracker.domain.controller.UploadController
import java.util.UUID

class FakeMediaProjectionController(
    var tokenValid: Boolean = true
) : MediaProjectionController {

    override suspend fun isConsentTokenValid(): Boolean = tokenValid

    override suspend fun captureVirtualDisplay(): ByteArray {
        if (!tokenValid) throw IllegalStateException("Consent token expired")
        return ByteArray(1024) { 0xFF.toByte() }
    }

    override suspend fun savePngToCache(imageBytes: ByteArray): String {
        return "/data/user/0/com.example.game_tracker/cache/screenshot_${UUID.randomUUID()}.png"
    }
}

class FakeUploadController : UploadController {
    override suspend fun enqueueUploadWorker(localFilePath: String, destinationUrl: String): String {
        return "work_upload_${UUID.randomUUID()}"
    }
}

class FakeCameraController(
    var cameraAvailable: Boolean = true,
    var permissionGranted: Boolean = true
) : com.example.game_tracker.domain.controller.CameraController {

    override suspend fun isCameraAvailable(): Boolean = cameraAvailable
    override suspend fun isCameraPermissionGranted(): Boolean = permissionGranted

    override suspend fun captureStillPhoto(cameraFacing: String): String {
        if (!permissionGranted) throw IllegalStateException("Camera permission denied")
        return "/data/user/0/com.example.game_tracker/cache/photo_${cameraFacing.lowercase()}_${UUID.randomUUID()}.jpg"
    }
}

class FakeLocationController(
    var gpsAvailable: Boolean = true,
    var permissionGranted: Boolean = true,
    var latitude: Double = 37.7749,
    var longitude: Double = -122.4194
) : com.example.game_tracker.domain.controller.LocationController {

    override suspend fun isGpsAvailable(): Boolean = gpsAvailable
    override suspend fun isLocationPermissionGranted(): Boolean = permissionGranted

    override suspend fun getSingleLocationFix(highAccuracy: Boolean): Pair<Double, Double> {
        if (!permissionGranted) throw IllegalStateException("Location permission denied")
        return Pair(latitude, longitude)
    }
}

class FakeWebRtcController(
    var supported: Boolean = true,
    var initializeSuccess: Boolean = true
) : com.example.game_tracker.domain.controller.WebRtcController {

    override suspend fun isWebRtcSupported(): Boolean = supported
    override suspend fun initializePeerConnection(streamType: String): Boolean = initializeSuccess

    override suspend fun processSdpOffer(sdpOffer: String): String {
        return "v=0\r\no=- 123456 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\na=sendrecv\r\n"
    }

    override suspend fun stopStreamSession() {
        // Stop stream
    }
}



