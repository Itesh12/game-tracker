package com.example.game_tracker.domain.controller

interface MediaProjectionController {
    suspend fun isConsentTokenValid(): Boolean
    suspend fun captureVirtualDisplay(): ByteArray
    suspend fun savePngToCache(imageBytes: ByteArray): String
}

interface UploadController {
    suspend fun enqueueUploadWorker(localFilePath: String, destinationUrl: String): String
}

interface CameraController {
    suspend fun isCameraAvailable(): Boolean
    suspend fun isCameraPermissionGranted(): Boolean
    suspend fun captureStillPhoto(cameraFacing: String): String
}

interface LocationController {
    suspend fun isGpsAvailable(): Boolean
    suspend fun isLocationPermissionGranted(): Boolean
    suspend fun getSingleLocationFix(highAccuracy: Boolean): Pair<Double, Double>
}


