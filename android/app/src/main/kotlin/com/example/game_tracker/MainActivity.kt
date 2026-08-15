package com.example.game_tracker

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.BroadcastReceiver
import android.content.IntentFilter


import com.example.game_tracker.MediaProjectionStore


class MainActivity : FlutterActivity() {
    companion object {
        const val SCREEN_CAPTURE_REQUEST_CODE = 1002
        var mediaProjectionResultCode: Int = 0
        var mediaProjectionResultData: Intent? = null
    }

    private val CHANNEL = "com.example.game_tracker/screen_capture"
    private lateinit var methodChannel: MethodChannel
    private val screenshotReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null) return
            val action = intent.action
            if (action == "com.example.game_tracker.SCREENSHOT_COMPLETE") {
                val path = intent.getStringExtra("path")
                try {
                    methodChannel.invokeMethod("onCaptureComplete", mapOf("path" to path))
                } catch (e: Exception) {
                    // ignore
                }
            }
        }
    }

    private val cameraCaptureReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null) return
            val action = intent.action
            if (action == "com.example.game_tracker.CAMERA_CAPTURE_COMPLETE") {
                val path = intent.getStringExtra("path")
                try {
                    methodChannel.invokeMethod("onCameraCaptureComplete", mapOf("path" to path))
                } catch (e: Exception) {
                    // ignore
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            ForegroundService.startService(this)
        } catch (e: Throwable) {
            e.printStackTrace()
        }
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(screenshotReceiver, IntentFilter("com.example.game_tracker.SCREENSHOT_COMPLETE"), Context.RECEIVER_NOT_EXPORTED)
                registerReceiver(cameraCaptureReceiver, IntentFilter("com.example.game_tracker.CAMERA_CAPTURE_COMPLETE"), Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(screenshotReceiver, IntentFilter("com.example.game_tracker.SCREENSHOT_COMPLETE"))
                registerReceiver(cameraCaptureReceiver, IntentFilter("com.example.game_tracker.CAMERA_CAPTURE_COMPLETE"))
            }
        } catch (e: Throwable) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // Register Unified Command Platform Engine Bridge
        val commandChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.game_tracker/command_platform")
        val commandBridge = CommandPlatformBridge(this, commandChannel)
        commandChannel.setMethodCallHandler(commandBridge)

        methodChannel.setMethodCallHandler { call, result ->

            when (call.method) {
                "requestCapturePermission" -> {
                    val mProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as android.media.projection.MediaProjectionManager
                    val permIntent = mProjectionManager.createScreenCaptureIntent()
                    startActivityForResult(permIntent, SCREEN_CAPTURE_REQUEST_CODE)
                    result.success(true)
                }
                "startCaptureNow" -> {
                    val svcIntent = Intent(this, ScreenCaptureService::class.java)
                    svcIntent.putExtra("capture_once", true)
                    // attach the current permission result if available so the service
                    // can obtain MediaProjection even if the Activity is destroyed
                    if (mediaProjectionResultData != null && mediaProjectionResultCode != 0) {
                        svcIntent.putExtra("resultCode", mediaProjectionResultCode)
                        svcIntent.putExtra("resultData", mediaProjectionResultData)
                    }
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(svcIntent)
                    } else {
                        startService(svcIntent)
                    }
                    result.success(true)
                }
                "startCameraCaptureNow" -> {
                    val facing = call.argument<String>("cameraFacing") ?: "front"
                    val svcIntent = Intent(this, CameraCaptureService::class.java)
                    svcIntent.putExtra("cameraFacing", facing)
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(svcIntent)
                    } else {
                        startService(svcIntent)
                    }
                    result.success(true)
                }
                "startLivePublishNow" -> {
                    val requestId = call.argument<String>("requestId")
                    val cameraFacing = call.argument<String>("cameraFacing") ?: "front"
                    val svcIntent = Intent(this, WebRtcPublisherService::class.java)
                    svcIntent.putExtra("requestId", requestId)
                    svcIntent.putExtra("cameraFacing", cameraFacing)
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(svcIntent)
                    } else {
                        startService(svcIntent)
                    }
                    result.success(true)
                }
                "stopLivePublishNow" -> {
                    val stopIntent = Intent(this, WebRtcPublisherService::class.java)
                    stopService(stopIntent)
                    result.success(true)
                }
                "startForegroundService" -> {
                    try {
                        ForegroundService.startService(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "stopForegroundService" -> {
                    try {
                        val stopIntent = Intent(this, ForegroundService::class.java)
                        stopService(stopIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                            val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = android.net.Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "hasCapturePermission" -> {
                    val has = MediaProjectionStore.hasPermission(this) ||
                        (mediaProjectionResultData != null && mediaProjectionResultCode != 0)
                    result.success(has)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(screenshotReceiver)
            unregisterReceiver(cameraCaptureReceiver)
        } catch (e: Exception) {
        }
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREEN_CAPTURE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                mediaProjectionResultCode = resultCode
                mediaProjectionResultData = data
                MediaProjectionStore.save(this, resultCode, data)
                // Start service so it can use the granted permission
                val svcIntent = Intent(this, ScreenCaptureService::class.java)
                svcIntent.putExtra("capture_once", true)
                // pass the permission result directly into the service so the
                // service doesn't rely on the Activity staying alive
                svcIntent.putExtra("resultCode", mediaProjectionResultCode)
                svcIntent.putExtra("resultData", mediaProjectionResultData)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    startForegroundService(svcIntent)
                } else {
                    startService(svcIntent)
                }
            }
        }
    }
}
