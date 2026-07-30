package com.example.game_tracker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.ImageFormat
import android.graphics.PixelFormat
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.util.DisplayMetrics
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream

class ScreenCaptureService : Service() {

    private var mediaProjection: MediaProjection? = null
    private var imageReader: ImageReader? = null
    private var handler: Handler? = null

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(ForegroundService.CHANNEL_ID, "System Service", NotificationManager.IMPORTANCE_MIN).apply {
                setShowBadge(false)
                setSound(null, null)
            }
            val mgr = getSystemService(NotificationManager::class.java)
            mgr?.createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification: Notification = createNotification()
        startForeground(ForegroundService.NOTIFICATION_ID, notification)

        val captureOnce = intent?.getBooleanExtra("capture_once", false) ?: false

        // Prefer the permission data passed in the start Intent. Fall back to
        // the MainActivity static holder only if necessary.
        val resultCodeFromIntent = intent?.getIntExtra("resultCode", 0) ?: 0
        val resultDataFromIntent = intent?.getParcelableExtra<Intent>("resultData")
        val resultCode = if (resultCodeFromIntent != 0) resultCodeFromIntent else MainActivity.mediaProjectionResultCode
        val resultData = resultDataFromIntent ?: MainActivity.mediaProjectionResultData

        if (resultData != null && resultCode != 0) {
            val mProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = mProjectionManager.getMediaProjection(resultCode, resultData)
            if (captureOnce) {
                captureAndSaveOnce()
            }
        }

        // Keep the service sticky so it can continue running/restart for
        // ongoing background work. We still stop the service when done.
        return START_STICKY
    }

    private fun captureAndSaveOnce() {
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        wm.defaultDisplay.getRealMetrics(metrics)
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val density = metrics.densityDpi

        imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)

        val handlerThread = HandlerThread("screencap")
        handlerThread.start()
        handler = Handler(handlerThread.looper)

        val virtualDisplay = mediaProjection?.createVirtualDisplay(
            "screencap",
            width,
            height,
            density,
            0,
            imageReader?.surface,
            null,
            handler
        )

        imageReader?.setOnImageAvailableListener({ reader ->
            val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
            val plane = image.planes[0]
            val buffer = plane.buffer
            val pixelStride = plane.pixelStride
            val rowStride = plane.rowStride
            val rowPadding = rowStride - pixelStride * width

            val bmp = Bitmap.createBitmap(width + rowPadding / pixelStride, height, Bitmap.Config.ARGB_8888)
            bmp.copyPixelsFromBuffer(buffer)
            image.close()

            val cropped = Bitmap.createBitmap(bmp, 0, 0, width, height)

            try {
                val cacheDir = cacheDir
                val outFile = File(cacheDir, "screencap_")
                val file = File.createTempFile("screencap_", ".png", cacheDir)
                val fos = FileOutputStream(file)
                cropped.compress(Bitmap.CompressFormat.PNG, 100, fos)
                fos.flush()
                fos.close()

                // Broadcast result path
                val done = Intent("com.example.game_tracker.SCREENSHOT_COMPLETE")
                done.putExtra("path", file.absolutePath)
                sendBroadcast(done)
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                cleanup()
                stopSelf()
            }
        }, handler)
    }

    private fun cleanup() {
        try {
            imageReader?.close()
            imageReader = null
            mediaProjection?.stop()
            mediaProjection = null
            handler?.looper?.quitSafely()
            handler = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotification(): Notification {
        val builder = NotificationCompat.Builder(this, ForegroundService.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_def_app_icon)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setOngoing(true)
            .setSilent(true)
        return builder.build()
    }
}
