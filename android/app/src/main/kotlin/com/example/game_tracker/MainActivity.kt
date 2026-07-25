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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ForegroundService.startService(this)
        registerReceiver(screenshotReceiver, IntentFilter("com.example.game_tracker.SCREENSHOT_COMPLETE"))
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(svcIntent)
                    } else {
                        startService(svcIntent)
                    }
                    result.success(true)
                }
                "hasCapturePermission" -> {
                    val has = mediaProjectionResultData != null && mediaProjectionResultCode != 0
                    result.success(has)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(screenshotReceiver)
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
                // Start service so it can use the granted permission
                val svcIntent = Intent(this, ScreenCaptureService::class.java)
                svcIntent.putExtra("capture_once", true)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    startForegroundService(svcIntent)
                } else {
                    startService(svcIntent)
                }
            }
        }
    }
}
