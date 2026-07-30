package com.example.game_tracker

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.ImageFormat
import android.hardware.camera2.*
import android.media.ImageReader
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.util.Size
import androidx.core.app.NotificationCompat
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import java.io.File
import java.io.FileOutputStream

class CameraCaptureService : Service() {
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var handler: Handler? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(ForegroundService.NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA)
        } else {
            startForeground(ForegroundService.NOTIFICATION_ID, notification)
        }

        val facing = intent?.getStringExtra("cameraFacing") ?: "front"
        val requestId = intent?.getStringExtra("requestId")

        startCapture(facing, requestId)

        return START_NOT_STICKY
    }

    private fun startCapture(facing: String, requestId: String?) {
        val handlerThread = HandlerThread("camera_capture")
        handlerThread.start()
        handler = Handler(handlerThread.looper)

        val manager = getSystemService(CAMERA_SERVICE) as CameraManager
        try {
            val cameraId = manager.cameraIdList.firstOrNull { id ->
                val characteristics = manager.getCameraCharacteristics(id)
                val lens = characteristics.get(CameraCharacteristics.LENS_FACING)
                if (facing == "back") lens == CameraCharacteristics.LENS_FACING_BACK
                else lens == CameraCharacteristics.LENS_FACING_FRONT
            } ?: manager.cameraIdList.first()

            val characteristics = manager.getCameraCharacteristics(cameraId)
            val sizes = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                ?.getOutputSizes(ImageFormat.JPEG)
            val chosen = sizes?.firstOrNull() ?: Size(1280, 720)

            imageReader = ImageReader.newInstance(chosen.width, chosen.height, ImageFormat.JPEG, 2)
            imageReader?.setOnImageAvailableListener({ reader ->
                val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
                val buffer = image.planes[0].buffer
                val bytes = ByteArray(buffer.remaining())
                buffer.get(bytes)
                image.close()

                try {
                    val cache = cacheDir
                    val file = File.createTempFile("camera_capture_", ".jpg", cache)
                    val fos = FileOutputStream(file)
                    fos.write(bytes)
                    fos.flush()
                    fos.close()

                    // Broadcast to Flutter app if alive
                    val done = Intent("com.example.game_tracker.CAMERA_CAPTURE_COMPLETE")
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
                                        "error" to "Background Cloudinary upload failed",
                                        "completedAt" to FieldValue.serverTimestamp()
                                    )
                                )
                            }
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                } finally {
                    stopSelf()
                }
            }, handler)

            manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(device: CameraDevice) {
                    cameraDevice = device
                    try {
                        val targets = listOf(imageReader!!.surface)
                        device.createCaptureSession(targets, object : CameraCaptureSession.StateCallback() {
                            override fun onConfigured(session: CameraCaptureSession) {
                                captureSession = session
                                val req = device.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
                                req.addTarget(imageReader!!.surface)
                                req.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                                session.capture(req.build(), object : CameraCaptureSession.CaptureCallback() {}, handler)
                            }

                            override fun onConfigureFailed(session: CameraCaptureSession) {
                                stopSelf()
                            }
                        }, handler)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        stopSelf()
                    }
                }

                override fun onDisconnected(device: CameraDevice) {
                    device.close()
                    stopSelf()
                }

                override fun onError(device: CameraDevice, error: Int) {
                    device.close()
                    stopSelf()
                }
            }, handler)

        } catch (e: Exception) {
            e.printStackTrace()
            stopSelf()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        try {
            captureSession?.close()
            cameraDevice?.close()
            imageReader?.close()
            handler?.looper?.quitSafely()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        super.onDestroy()
    }

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
