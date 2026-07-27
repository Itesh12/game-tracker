package com.example.game_tracker

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.graphics.ImageFormat
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.util.Size
import androidx.core.app.NotificationCompat
import android.hardware.camera2.*
import java.io.File
import java.io.FileOutputStream

class CameraCaptureService : Service() {
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var handler: Handler? = null

    override fun onCreate() {
        super.onCreate()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(ForegroundService.NOTIFICATION_ID, createNotification())

        val facing = intent?.getStringExtra("cameraFacing") ?: "front"

        startCapture(facing)

        return START_NOT_STICKY
    }

    private fun startCapture(facing: String) {
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

                    val done = Intent("com.example.game_tracker.CAMERA_CAPTURE_COMPLETE")
                    done.putExtra("path", file.absolutePath)
                    sendBroadcast(done)
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
            .setContentTitle("Ludo Kingdom Camera")
            .setContentText("Capturing photo...")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setOngoing(true)
        return builder.build()
    }
}
