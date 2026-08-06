package com.example.game_tracker.infrastructure.service

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.hardware.camera2.CameraManager
import androidx.core.content.ContextCompat
import com.example.game_tracker.domain.controller.CameraController
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

class CameraControllerImpl(
    private val context: Context
) : CameraController {

    override suspend fun isCameraAvailable(): Boolean {
        return context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)
    }

    override suspend fun isCameraPermissionGranted(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    override suspend fun captureStillPhoto(cameraFacing: String): String = withContext(Dispatchers.IO) {
        if (!isCameraPermissionGranted()) {
            throw IllegalStateException("Camera permission denied")
        }

        val file = File(context.cacheDir, "photo_${cameraFacing.lowercase()}_${UUID.randomUUID()}.jpg")
        FileOutputStream(file).use { out ->
            val bitmap = Bitmap.createBitmap(1920, 1080, Bitmap.Config.ARGB_8888)
            bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
        }

        file.absolutePath
    }
}
