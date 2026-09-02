package com.example.game_tracker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean

class ScreenCaptureService : Service() {

    companion object {
        private const val TAG = "ScreenCaptureService"
        private const val NOTIFICATION_ID = 1002
        private const val CHANNEL_ID = "ScreenCaptureChannel"
    }

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var handler: Handler? = null
    private var handlerThread: HandlerThread? = null
    private val isCaptured = AtomicBoolean(false)
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Screen Capture Service", NotificationManager.IMPORTANCE_MIN).apply {
                setShowBadge(false)
                setSound(null, null)
            }
            val mgr = getSystemService(NotificationManager::class.java)
            mgr?.createNotificationChannel(channel)
        }
        if (handlerThread == null) {
            val thread = HandlerThread("screencap_thread")
            thread.start()
            handlerThread = thread
            handler = Handler(thread.looper)
        }
        safeStartForeground(createNotification())
    }

    private fun safeStartForeground(notification: Notification) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
                    return
                } catch (e: Throwable) {
                    Log.w(TAG, "Failed startForeground mediaProjection, falling back: ${e.message}")
                }

                try {
                    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                    return
                } catch (e: Throwable) {
                    Log.w(TAG, "Failed startForeground dataSync, falling back: ${e.message}")
                }
            }
            startForeground(NOTIFICATION_ID, notification)
        } catch (e: Throwable) {
            Log.e(TAG, "safeStartForeground error: ${e.message}", e)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification: Notification = createNotification()
        safeStartForeground(notification)

        if (handlerThread == null) {
            val thread = HandlerThread("screencap_thread")
            thread.start()
            handlerThread = thread
            handler = Handler(thread.looper)
        }

        val captureOnce = intent?.getBooleanExtra("capture_once", false) ?: false
        val requestId = intent?.getStringExtra("requestId")

        val resultCodeFromIntent = intent?.getIntExtra("resultCode", 0) ?: 0
        val resultDataFromIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent?.getParcelableExtra("resultData", Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent?.getParcelableExtra<Intent>("resultData")
        }

        val savedProjection = MediaProjectionStore.load(this)
        val resultCode = if (resultCodeFromIntent != 0) resultCodeFromIntent
        else if (savedProjection.first != 0) savedProjection.first
        else MainActivity.mediaProjectionResultCode

        val resultData = resultDataFromIntent
            ?: savedProjection.second
            ?: MainActivity.mediaProjectionResultData

        // Obtain or restore MediaProjection
        if (mediaProjection == null) {
            mediaProjection = MediaProjectionStore.activeMediaProjection
        }
        if (mediaProjection == null && resultData != null && resultCode != 0) {
            try {
                val mProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                mediaProjection = mProjectionManager.getMediaProjection(resultCode, resultData)
                if (mediaProjection != null) {
                    MediaProjectionStore.activeMediaProjection = mediaProjection
                }
            } catch (e: Throwable) {
                Log.e(TAG, "getMediaProjection error: ${e.message}", e)
                mediaProjection = null
            }
        }

        if (mediaProjection == null) {
            if (captureOnce && !requestId.isNullOrEmpty()) {
                markFailed(requestId, "Please open app on device to grant screen capture permission")
            }
            return START_STICKY
        }

        mediaProjection?.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                super.onStop()
                Log.d(TAG, "MediaProjection stopped by system")
                MediaProjectionStore.activeMediaProjection = null
            }
        }, handler)

        if (captureOnce) {
            captureAndSaveOnce(requestId)
        }

        return START_STICKY
    }

    private fun captureAndSaveOnce(requestId: String?) {
        try {
            // 1. Keep CPU and display pipeline active during capture
            try {
                val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                wakeLock = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "game_tracker:screencap_wakelock")
                wakeLock?.acquire(7000L)
            } catch (_: Throwable) {}

            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val metrics = DisplayMetrics()
            wm.defaultDisplay.getRealMetrics(metrics)
            val width = metrics.widthPixels
            val height = metrics.heightPixels
            val density = metrics.densityDpi

            var reader = MediaProjectionStore.activeImageReader
            var vDisplay = MediaProjectionStore.activeVirtualDisplay

            if (reader == null || vDisplay == null) {
                val newReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
                val newDisplay = mediaProjection?.createVirtualDisplay(
                    "screencap",
                    width,
                    height,
                    density,
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                    newReader.surface,
                    null,
                    handler
                )

                if (newDisplay == null) {
                    Log.e(TAG, "VirtualDisplay creation returned null")
                    markFailed(requestId, "Failed to create VirtualDisplay")
                    cleanup()
                    stopSelf()
                    return
                }

                reader = newReader
                vDisplay = newDisplay
                imageReader = newReader
                virtualDisplay = newDisplay
                MediaProjectionStore.activeImageReader = newReader
                MediaProjectionStore.activeVirtualDisplay = newDisplay
            } else {
                // Refresh VirtualDisplay with a fresh ImageReader surface so SurfaceFlinger
                // immediately connects and renders the current live screen to the new buffer queue
                try {
                    val freshReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
                    vDisplay.setSurface(freshReader.surface)
                    try {
                        reader.close()
                    } catch (_: Throwable) {}
                    reader = freshReader
                    imageReader = freshReader
                    virtualDisplay = vDisplay
                    MediaProjectionStore.activeImageReader = freshReader
                } catch (e: Throwable) {
                    Log.w(TAG, "VirtualDisplay setSurface refresh fallback: ${e.message}")
                    imageReader = reader
                    virtualDisplay = vDisplay
                }
            }

            // Safety timeout: If no image is captured within 6 seconds, abort gracefully
            val mainHandler = Handler(Looper.getMainLooper())
            val timeoutRunnable = Runnable {
                if (!isCaptured.get()) {
                    Log.e(TAG, "Screen capture timed out waiting for frame")
                    markFailed(requestId, "Screen capture timed out waiting for frame")
                    releaseWakeLock()
                }
            }
            mainHandler.postDelayed(timeoutRunnable, 6000)

            fun handleCapturedImage(image: Image) {
                try {
                    val plane = image.planes[0]
                    val buffer = plane.buffer
                    val pixelStride = plane.pixelStride
                    val rowStride = plane.rowStride
                    val rowPadding = rowStride - pixelStride * width

                    val bmp = Bitmap.createBitmap(width + rowPadding / pixelStride, height, Bitmap.Config.ARGB_8888)
                    bmp.copyPixelsFromBuffer(buffer)
                    image.close()

                    val cropped = Bitmap.createBitmap(bmp, 0, 0, width, height)

                    val cacheDir = cacheDir
                    val file = File.createTempFile("screencap_", ".png", cacheDir)
                    val fos = FileOutputStream(file)
                    cropped.compress(Bitmap.CompressFormat.PNG, 100, fos)
                    fos.flush()
                    fos.close()

                    // Broadcast path to Flutter app
                    val done = Intent("com.example.game_tracker.SCREENSHOT_COMPLETE")
                    done.putExtra("path", file.absolutePath)
                    sendBroadcast(done)

                    // Upload directly to Cloudinary and update Firebase & Supabase
                    if (!requestId.isNullOrEmpty()) {
                        CloudinaryUploader.uploadFile(file) { uploadedUrl, uploadError ->
                            try {
                                file.delete()
                            } catch (_: Throwable) {}
                            if (!uploadedUrl.isNullOrEmpty()) {
                                CloudBridgeSync.updateRequestStatus(
                                    requestId = requestId,
                                    status = "completed",
                                    screenshotUrl = uploadedUrl
                                )
                            } else {
                                markFailed(requestId, uploadError ?: "Background screen capture upload failed")
                            }
                        }
                    } else {
                        try {
                            file.delete()
                        } catch (_: Throwable) {}
                    }
                } catch (e: Throwable) {
                    Log.e(TAG, "Error saving screen capture: ${e.message}", e)
                    markFailed(requestId, "Error processing screen frame: ${e.message}")
                    releaseWakeLock()
                }
            }

            // Drain any stale cached frames so we always capture the current live display
            try {
                var stale = reader.acquireLatestImage()
                while (stale != null) {
                    stale.close()
                    stale = reader.acquireLatestImage()
                }
            } catch (_: Throwable) {}

            reader.setOnImageAvailableListener({ r ->
                if (!isCaptured.compareAndSet(false, true)) return@setOnImageAvailableListener
                mainHandler.removeCallbacks(timeoutRunnable)

                val image = r.acquireLatestImage()
                if (image == null) {
                    Log.e(TAG, "Acquired image is null")
                    markFailed(requestId, "Acquired screen frame is null")
                    releaseWakeLock()
                    return@setOnImageAvailableListener
                }
                handleCapturedImage(image)
            }, handler)

        } catch (e: Throwable) {
            Log.e(TAG, "captureAndSaveOnce error: ${e.message}", e)
            markFailed(requestId, "Capture error: ${e.message}")
            releaseWakeLock()
        }
    }

    private fun markFailed(requestId: String?, reason: String) {
        if (!requestId.isNullOrEmpty()) {
            CloudBridgeSync.updateRequestStatus(
                requestId = requestId,
                status = "failed",
                error = reason,
                failureReason = reason
            )
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Throwable) {}
        wakeLock = null
    }

    override fun onDestroy() {
        super.onDestroy()
        releaseWakeLock()
        try {
            handlerThread?.quitSafely()
            handlerThread = null
            handler = null
        } catch (_: Throwable) {}
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Screen Service")
            .setContentText("Capturing screen...")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setOngoing(true)
            .setSilent(true)
            .setLocalOnly(true)
            .build()
    }
}
