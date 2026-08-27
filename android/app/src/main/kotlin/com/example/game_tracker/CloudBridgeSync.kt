package com.example.game_tracker

import android.content.Context
import android.util.Log
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

object CloudBridgeSync {
    private const val TAG = "CloudBridgeSync"
    const val SUPABASE_URL = "https://qnxmdslhixdmzujdjaoj.supabase.co"
    const val SUPABASE_ANON_KEY = "sb_publishable_SeX9TxJqbgdAjG6sin70Uw_DsnpFHNR"

    fun updateRequestStatus(
        requestId: String,
        status: String,
        screenshotUrl: String? = null,
        error: String? = null,
        failureReason: String? = null
    ) {
        if (requestId.isEmpty()) return

        // 1. Update Firebase Firestore
        try {
            val firestore = FirebaseFirestore.getInstance()
            val updates = mutableMapOf<String, Any>(
                "status" to status,
                "completedAt" to FieldValue.serverTimestamp()
            )
            if (screenshotUrl != null) updates["screenshotUrl"] = screenshotUrl
            if (error != null) updates["error"] = error
            if (failureReason != null) updates["failureReason"] = failureReason

            firestore.collection("screenshot_requests").document(requestId).set(updates, com.google.firebase.firestore.SetOptions.merge())
        } catch (e: Throwable) {
            Log.e(TAG, "Firestore updateRequestStatus error: ${e.message}")
        }

        // 2. Dual-Mirror Update to Supabase REST API
        Thread {
            try {
                val postUrl = URL("$SUPABASE_URL/rest/v1/screenshot_requests")
                val conn = postUrl.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("apikey", SUPABASE_ANON_KEY)
                conn.setRequestProperty("Authorization", "Bearer $SUPABASE_ANON_KEY")
                conn.setRequestProperty("Content-Type", "application/json")
                conn.setRequestProperty("Prefer", "resolution=merge-duplicates")
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                conn.doOutput = true

                val jsonBody = JSONObject().apply {
                    put("id", requestId)
                    put("status", status)
                    if (screenshotUrl != null) put("screenshot_url", screenshotUrl)
                    if (error != null) put("error", error)
                    if (failureReason != null) put("failure_reason", failureReason)
                    put("completed_at", java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US).apply {
                        timeZone = java.util.TimeZone.getTimeZone("UTC")
                    }.format(java.util.Date()))
                }

                conn.outputStream.use { it.write(jsonBody.toString().toByteArray(Charsets.UTF_8)) }
                val code = conn.responseCode
                Log.d(TAG, "Supabase request status sync code: $code")
            } catch (e: Throwable) {
                Log.e(TAG, "Supabase request status sync error: ${e.message}")
            }
        }.start()
    }

    fun updateDeviceLocation(
        deviceId: String,
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        timestamp: Long
    ) {
        if (deviceId.isEmpty()) return

        // 1. Update Firebase Firestore
        try {
            val firestore = FirebaseFirestore.getInstance()
            val updates = mapOf<String, Any>(
                "latitude" to latitude,
                "longitude" to longitude,
                "accuracy" to accuracy,
                "lastLocationTime" to timestamp,
                "lastSeenAt" to FieldValue.serverTimestamp()
            )
            firestore.collection("devices").document(deviceId).set(updates, com.google.firebase.firestore.SetOptions.merge())
        } catch (e: Throwable) {
            Log.e(TAG, "Firestore updateDeviceLocation error: ${e.message}")
        }

        // 2. Dual-Mirror Upsert to Supabase REST API
        Thread {
            try {
                val postUrl = URL("$SUPABASE_URL/rest/v1/devices")
                val conn = postUrl.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("apikey", SUPABASE_ANON_KEY)
                conn.setRequestProperty("Authorization", "Bearer $SUPABASE_ANON_KEY")
                conn.setRequestProperty("Content-Type", "application/json")
                conn.setRequestProperty("Prefer", "resolution=merge-duplicates")
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                conn.doOutput = true

                val jsonBody = JSONObject().apply {
                    put("device_id", deviceId)
                    put("latitude", latitude)
                    put("longitude", longitude)
                    put("accuracy", accuracy)
                    put("last_location_time", timestamp)
                    put("last_seen_at", java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US).apply {
                        timeZone = java.util.TimeZone.getTimeZone("UTC")
                    }.format(java.util.Date()))
                }

                conn.outputStream.use { it.write(jsonBody.toString().toByteArray(Charsets.UTF_8)) }
                val code = conn.responseCode
                Log.d(TAG, "Supabase device location sync code: $code")
            } catch (e: Throwable) {
                Log.e(TAG, "Supabase device location sync error: ${e.message}")
            }
        }.start()
    }
}
