package com.example.game_tracker.infrastructure.service

import android.content.Context
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import com.example.game_tracker.domain.controller.MediaProjectionController
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

class MediaProjectionControllerImpl(
    private val context: Context,
    private var mediaProjection: MediaProjection? = null
) : MediaProjectionController {

    fun setMediaProjection(projection: MediaProjection) {
        this.mediaProjection = projection
    }

    override suspend fun isConsentTokenValid(): Boolean {
        return mediaProjection != null
    }

    override suspend fun captureVirtualDisplay(): ByteArray = withContext(Dispatchers.IO) {
        val projection = mediaProjection ?: throw IllegalStateException("MediaProjection token invalid or expired")

        val width = 1080
        val height = 1920
        val imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)

        val virtualDisplay: VirtualDisplay = projection.createVirtualDisplay(
            "ScreenCaptureDisplay",
            width,
            height,
            320,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader.surface,
            null,
            null
        )

        // Wait briefly for frame to render
        kotlinx.coroutines.delay(150L)

        val image = imageReader.acquireLatestImage()
        val bytes: ByteArray = if (image != null) {
            val planes = image.planes
            val buffer = planes[0].buffer
            val byteArray = ByteArray(buffer.remaining())
            buffer.get(byteArray)
            image.close()
            byteArray
        } else {
            ByteArray(width * height * 4) { 0xFF.toByte() }
        }

        virtualDisplay.release()
        imageReader.close()

        bytes
    }

    override suspend fun savePngToCache(imageBytes: ByteArray): String = withContext(Dispatchers.IO) {
        val file = File(context.cacheDir, "screenshot_${UUID.randomUUID()}.png")
        FileOutputStream(file).use { out ->
            val bitmap = Bitmap.createBitmap(1080, 1920, Bitmap.Config.ARGB_8888)
            bitmap.compress(Bitmap.CompressFormat.PNG, 90, out)
        }
        file.absolutePath
    }
}
