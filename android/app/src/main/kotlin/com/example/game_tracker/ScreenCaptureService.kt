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
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
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

        if (resultData == null || resultCode == 0) {
            Log.e(TAG, "Missing MediaProjection resultCode or resultData")
            markFailed(requestId, "Screen capture permission missing or expired")
            stopSelf()
            return START_NOT_STICKY
        }

        // 2. Safely obtain MediaProjection
        mediaProjection = MediaProjectionStore.getOrCreateMediaProjection(this)
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
            Log.e(TAG, "MediaProjection is null after getMediaProjection call")
            markFailed(requestId, "Please open app on device to grant screen capture permission")
            stopSelf()
            return START_NOT_STICKY
        }

        // 3. Set up background handler thread
        val thread = HandlerThread("screencap_thread")
        thread.start()
        handlerThread = thread
        handler = Handler(thread.looper)

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

        return START_NOT_STICKY
    }

    private fun captureAndSaveOnce(requestId: String?) {
        try {
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val metrics = DisplayMetrics()
            wm.defaultDisplay.getRealMetrics(metrics)
            val width = metrics.widthPixels
            val height = metrics.heightPixels
            val density = metrics.densityDpi

            imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)

            virtualDisplay = mediaProjection?.createVirtualDisplay(
                "screencap",
                width,
                height,
                density,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                imageReader?.surface,
                null,
                handler
            )

            if (virtualDisplay == null) {
                Log.e(TAG, "VirtualDisplay creation returned null")
                markFailed(requestId, "Failed to create VirtualDisplay")
                cleanup()
                stopSelf()
                return
            }

            // Safety timeout: If no image is captured within 6 seconds, abort gracefully
            val mainHandler = Handler(Looper.getMainLooper())
            val timeoutRunnable = Runnable {
                if (!isCaptured.get()) {
                    Log.e(TAG, "Screen capture timed out waiting for frame")
                    markFailed(requestId, "Screen capture timed out")
                    cleanup()
                    stopSelf()
                }
            }
            mainHandler.postDelayed(timeoutRunnable, 6000)

            imageReader?.setOnImageAvailableListener({ reader ->
                if (!isCaptured.compareAndSet(false, true)) return@setOnImageAvailableListener
                mainHandler.removeCallbacks(timeoutRunnable)

                val image = reader.acquireLatestImage()
                if (image == null) {
                    Log.e(TAG, "Acquired image is null")
                    markFailed(requestId, "Acquired screen frame is null")
                    cleanup()
                    stopSelf()
                    return@setOnImageAvailableListener
                }

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
                    }
                } catch (e: Throwable) {
                    Log.e(TAG, "Error saving screen capture: ${e.message}", e)
                    markFailed(requestId, "Error processing screen frame: ${e.message}")
                } finally {
                    cleanup()
                    stopSelf()
                }
            }, handler)

        } catch (e: Throwable) {
            Log.e(TAG, "captureAndSaveOnce error: ${e.message}", e)
            markFailed(requestId, "Capture error: ${e.message}")
            cleanup()
            stopSelf()
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

    private fun cleanup() {
        try {
            virtualDisplay?.release()
            virtualDisplay = null
            imageReader?.close()
            imageReader = null
            handlerThread?.quitSafely()
            handlerThread = null
            handler = null
        } catch (e: Exception) {
            Log.e(TAG, "Cleanup error: ${e.message}")
        }
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
