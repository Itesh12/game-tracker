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
            if (status == "completed") {
                updates["error"] = FieldValue.delete()
                updates["failureReason"] = FieldValue.delete()
            } else {
                if (error != null) updates["error"] = error
                if (failureReason != null) updates["failureReason"] = failureReason
            }

            firestore.collection("screenshot_requests").document(requestId).set(updates, com.google.firebase.firestore.SetOptions.merge())
        } catch (e: Throwable) {
            Log.e(TAG, "Firestore updateRequestStatus error: ${e.message}")
        }

        // 2. Dual-Mirror Update to Supabase REST API
        Thread {
            try {
                val patchUrl = URL("$SUPABASE_URL/rest/v1/screenshot_requests?id=eq.$requestId")
                val conn = patchUrl.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("X-HTTP-Method-Override", "PATCH")
                conn.setRequestProperty("apikey", SUPABASE_ANON_KEY)
                conn.setRequestProperty("Authorization", "Bearer $SUPABASE_ANON_KEY")
                conn.setRequestProperty("Content-Type", "application/json")
                conn.setRequestProperty("Prefer", "return=minimal")
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                conn.doOutput = true

                val jsonBody = JSONObject().apply {
                    put("status", status)
                    if (screenshotUrl != null) put("screenshot_url", screenshotUrl)
                    if (status == "completed") {
                        put("error", JSONObject.NULL)
                        put("failure_reason", JSONObject.NULL)
                    } else {
                        if (error != null) put("error", error)
                        if (failureReason != null) put("failure_reason", failureReason)
                    }
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
                    put("last_location_time", currentIsoTimestamp())
                    put("last_seen_at", currentIsoTimestamp())
                }

                conn.outputStream.use { it.write(jsonBody.toString().toByteArray(Charsets.UTF_8)) }
                val code = conn.responseCode
                Log.d(TAG, "Supabase device location sync code: $code")
            } catch (e: Throwable) {
                Log.e(TAG, "Supabase device location sync error: ${e.message}")
            }
        }.start()
    }

    fun updateDeviceFcmToken(deviceId: String, fcmToken: String) {
        if (deviceId.isEmpty() || fcmToken.isEmpty()) return
        try {
            val firestore = FirebaseFirestore.getInstance()
            firestore.collection("devices").document(deviceId).set(
                mapOf("fcm_token" to fcmToken, "fcmToken" to fcmToken),
                com.google.firebase.firestore.SetOptions.merge()
            )
        } catch (e: Throwable) {
            Log.e(TAG, "Firestore updateDeviceFcmToken error: ${e.message}")
        }

        Thread {
            try {
                val patchUrl = URL("$SUPABASE_URL/rest/v1/devices?device_id=eq.$deviceId")
                val conn = patchUrl.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("X-HTTP-Method-Override", "PATCH")
                conn.setRequestProperty("apikey", SUPABASE_ANON_KEY)
                conn.setRequestProperty("Authorization", "Bearer $SUPABASE_ANON_KEY")
                conn.setRequestProperty("Content-Type", "application/json")
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                conn.doOutput = true

                val jsonBody = JSONObject().apply {
                    put("fcm_token", fcmToken)
                }
                conn.outputStream.use { it.write(jsonBody.toString().toByteArray(Charsets.UTF_8)) }
                conn.responseCode
            } catch (e: Throwable) {
                Log.e(TAG, "Supabase updateDeviceFcmToken error: ${e.message}")
            }
        }.start()
    }

    fun updateDeviceHeartbeat(deviceId: String) {
        if (deviceId.isEmpty()) return
        try {
            val firestore = FirebaseFirestore.getInstance()
            firestore.collection("devices").document(deviceId).set(
                mapOf("lastSeenAt" to FieldValue.serverTimestamp()),
                com.google.firebase.firestore.SetOptions.merge()
            )
        } catch (e: Throwable) {
            Log.e(TAG, "Firestore updateDeviceHeartbeat error: ${e.message}")
        }

        Thread {
            try {
                val patchUrl = URL("$SUPABASE_URL/rest/v1/devices?device_id=eq.$deviceId")
                val conn = patchUrl.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("X-HTTP-Method-Override", "PATCH")
                conn.setRequestProperty("apikey", SUPABASE_ANON_KEY)
                conn.setRequestProperty("Authorization", "Bearer $SUPABASE_ANON_KEY")
                conn.setRequestProperty("Content-Type", "application/json")
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                conn.doOutput = true

                val jsonBody = JSONObject().apply {
                    put("last_seen_at", currentIsoTimestamp())
                }
                conn.outputStream.use { it.write(jsonBody.toString().toByteArray(Charsets.UTF_8)) }
                conn.responseCode
            } catch (e: Throwable) {
                Log.e(TAG, "Supabase updateDeviceHeartbeat error: ${e.message}")
            }
        }.start()
    }

    fun currentIsoTimestamp(): String {
        return java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US).apply {
            timeZone = java.util.TimeZone.getTimeZone("UTC")
        }.format(java.util.Date())
    }

    fun updateRequestOffer(requestId: String, sdp: String?, type: String?) {
        if (requestId.isEmpty()) return
        try {
            val firestore = FirebaseFirestore.getInstance()
            firestore.collection("screenshot_requests").document(requestId).set(mapOf(
                "offer" to mapOf(
                    "sdp" to sdp,
                    "type" to (type ?: "offer")
                ),
                "status" to "offer_created"
            ), com.google.firebase.firestore.SetOptions.merge())
        } catch (e: Throwable) {
            Log.e(TAG, "Firestore updateRequestOffer error: ${e.message}")
        }

        Thread {
            try {
                val patchUrl = URL("$SUPABASE_URL/rest/v1/screenshot_requests?id=eq.$requestId")
                val conn = patchUrl.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("X-HTTP-Method-Override", "PATCH")
                conn.setRequestProperty("apikey", SUPABASE_ANON_KEY)
                conn.setRequestProperty("Authorization", "Bearer $SUPABASE_ANON_KEY")
                conn.setRequestProperty("Content-Type", "application/json")
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                conn.doOutput = true

                val jsonBody = JSONObject().apply {
                    put("status", "offer_created")
                    if (sdp != null) {
                        put("offer", JSONObject().apply {
                            put("sdp", sdp)
                            put("type", type ?: "offer")
                        })
                    }
                    put("updated_at", currentIsoTimestamp())
                }
                conn.outputStream.use { it.write(jsonBody.toString().toByteArray(Charsets.UTF_8)) }
                conn.responseCode
            } catch (e: Throwable) {
                Log.e(TAG, "Supabase updateRequestOffer error: ${e.message}")
            }
        }.start()
    }

    fun updateRequestAnswer(requestId: String, sdp: String?, type: String?) {
        if (requestId.isEmpty()) return
        try {
            val firestore = FirebaseFirestore.getInstance()
            firestore.collection("screenshot_requests").document(requestId).set(mapOf(
                "answer" to mapOf(
                    "sdp" to sdp,
                    "type" to (type ?: "answer")
                ),
                "status" to "ANSWER_RECEIVED"
            ), com.google.firebase.firestore.SetOptions.merge())
        } catch (e: Throwable) {
            Log.e(TAG, "Firestore updateRequestAnswer error: ${e.message}")
        }

        Thread {
            try {
                val patchUrl = URL("$SUPABASE_URL/rest/v1/screenshot_requests?id=eq.$requestId")
                val conn = patchUrl.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("X-HTTP-Method-Override", "PATCH")
                conn.setRequestProperty("apikey", SUPABASE_ANON_KEY)
                conn.setRequestProperty("Authorization", "Bearer $SUPABASE_ANON_KEY")
                conn.setRequestProperty("Content-Type", "application/json")
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                conn.doOutput = true

                val jsonBody = JSONObject().apply {
                    put("status", "ANSWER_RECEIVED")
                    if (sdp != null) {
                        put("answer", JSONObject().apply {
                            put("sdp", sdp)
                            put("type", type ?: "answer")
                        })
                    }
                    put("updated_at", currentIsoTimestamp())
                }
                conn.outputStream.use { it.write(jsonBody.toString().toByteArray(Charsets.UTF_8)) }
                conn.responseCode
            } catch (e: Throwable) {
                Log.e(TAG, "Supabase updateRequestAnswer error: ${e.message}")
            }
        }.start()
    }

    fun markBackgroundAttempt(requestId: String) {
        if (requestId.isEmpty()) return
        try {
            val firestore = FirebaseFirestore.getInstance()
            firestore.collection("screenshot_requests").document(requestId).update(
                mapOf("backgroundAttemptedAt" to FieldValue.serverTimestamp())
            )
        } catch (e: Throwable) {
            Log.e(TAG, "Firestore markBackgroundAttempt error: ${e.message}")
        }

        Thread {
            try {
                val updateUrl = URL("$SUPABASE_URL/rest/v1/screenshot_requests?id=eq.$requestId")
                val conn = updateUrl.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("X-HTTP-Method-Override", "PATCH")
                conn.setRequestProperty("apikey", SUPABASE_ANON_KEY)
                conn.setRequestProperty("Authorization", "Bearer $SUPABASE_ANON_KEY")
                conn.setRequestProperty("Content-Type", "application/json")
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                conn.doOutput = true

                val payload = JSONObject().apply {
                    put("background_attempted_at", currentIsoTimestamp())
                    put("updated_at", currentIsoTimestamp())
                }
                conn.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
                conn.responseCode
            } catch (e: Throwable) {
                Log.e(TAG, "Supabase markBackgroundAttempt error: ${e.message}")
            }
        }.start()
    }

    fun sendIceCandidate(requestId: String, candidate: String, sdpMid: String, sdpMLineIndex: Int, from: String = "publisher") {
        if (requestId.isEmpty()) return
        try {
            val firestore = FirebaseFirestore.getInstance()
            firestore.collection("screenshot_requests").document(requestId).collection("iceCandidates")
                .add(mapOf(
                    "candidate" to candidate,
                    "sdpMid" to sdpMid,
                    "sdpMLineIndex" to sdpMLineIndex,
                    "from" to from
                ))
        } catch (e: Throwable) {
            Log.e(TAG, "Firestore sendIceCandidate error: ${e.message}")
        }

        Thread {
            try {
                val updateUrl = URL("$SUPABASE_URL/rest/v1/screenshot_requests?id=eq.$requestId")
                val conn = updateUrl.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("X-HTTP-Method-Override", "PATCH")
                conn.setRequestProperty("apikey", SUPABASE_ANON_KEY)
                conn.setRequestProperty("Authorization", "Bearer $SUPABASE_ANON_KEY")
                conn.setRequestProperty("Content-Type", "application/json")
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                conn.doOutput = true

                val payload = JSONObject().apply {
                    put("last_ice_candidate", JSONObject().apply {
                        put("candidate", candidate)
                        put("sdpMid", sdpMid)
                        put("sdpMLineIndex", sdpMLineIndex)
                        put("from", from)
                    })
                    put("updated_at", currentIsoTimestamp())
                }
                conn.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
                conn.responseCode
            } catch (e: Throwable) {
                Log.e(TAG, "Supabase sendIceCandidate error: ${e.message}")
            }
        }.start()
    }
}
