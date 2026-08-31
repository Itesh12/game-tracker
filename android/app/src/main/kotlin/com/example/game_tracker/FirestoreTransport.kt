package com.example.game_tracker

import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.SetOptions

class FirestoreTransport : SignalingTransport {
    private val firestore = FirebaseFirestore.getInstance()
    private var docListener: ListenerRegistration? = null
    private var iceListener: ListenerRegistration? = null
    private var isListening = false

    override fun startListening(
        sessionId: String,
        onOffer: (String, String) -> Unit,
        onAnswer: (String, String) -> Unit,
        onIceCandidate: (String, String, Int) -> Unit
    ) {
        isListening = true
        try {
            val requestDoc = firestore.collection("screenshot_requests").document(sessionId)

            docListener = requestDoc.addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null) return@addSnapshotListener
                val data = snapshot.data ?: return@addSnapshotListener

                if (data.containsKey("offer")) {
                    val offer = data["offer"] as? Map<*, *>
                    val sdp = offer?.get("sdp") as? String
                    val type = offer?.get("type") as? String
                    if (!sdp.isNullOrEmpty() && !type.isNullOrEmpty()) {
                        onOffer(sdp, type)
                    }
                }

                if (data.containsKey("answer")) {
                    val answer = data["answer"] as? Map<*, *>
                    val sdp = answer?.get("sdp") as? String
                    val type = answer?.get("type") as? String
                    if (!sdp.isNullOrEmpty() && !type.isNullOrEmpty()) {
                        onAnswer(sdp, type)
                    }
                }
            }

            iceListener = requestDoc.collection("iceCandidates").addSnapshotListener { snapshots, error ->
                if (error != null || snapshots == null) return@addSnapshotListener
                for (change in snapshots.documentChanges) {
                    val data = change.document.data
                    val candidate = data["candidate"] as? String
                    val sdpMid = data["sdpMid"] as? String
                    val sdpMLineIndex = (data["sdpMLineIndex"] as? Long)?.toInt() ?: (data["sdpMLineIndex"] as? Int ?: 0)
                    if (!candidate.isNullOrEmpty() && !sdpMid.isNullOrEmpty()) {
                        onIceCandidate(candidate, sdpMid, sdpMLineIndex)
                    }
                }
            }
        } catch (_: Throwable) {}

        // Dual-Cloud Supabase Poller for Resilient WebRTC Signaling
        Thread {
            while (isListening) {
                try {
                    Thread.sleep(2000)
                    val url = java.net.URL("${CloudBridgeSync.SUPABASE_URL}/rest/v1/screenshot_requests?id=eq.$sessionId&select=*")
                    val conn = url.openConnection() as java.net.HttpURLConnection
                    conn.requestMethod = "GET"
                    conn.setRequestProperty("apikey", CloudBridgeSync.SUPABASE_ANON_KEY)
                    conn.setRequestProperty("Authorization", "Bearer ${CloudBridgeSync.SUPABASE_ANON_KEY}")
                    if (conn.responseCode == 200) {
                        val text = conn.inputStream.bufferedReader().use { it.readText() }
                        val arr = org.json.JSONArray(text)
                        if (arr.length() > 0) {
                            val obj = arr.getJSONObject(0)
                            val offerObj = obj.optJSONObject("offer")
                            if (offerObj != null) {
                                val sdp = offerObj.optString("sdp")
                                val type = offerObj.optString("type", "offer")
                                if (sdp.isNotEmpty()) onOffer(sdp, type)
                            }
                            val answerObj = obj.optJSONObject("answer")
                            if (answerObj != null) {
                                val sdp = answerObj.optString("sdp")
                                val type = answerObj.optString("type", "answer")
                                if (sdp.isNotEmpty()) onAnswer(sdp, type)
                            }
                            val iceObj = obj.optJSONObject("last_ice_candidate")
                            if (iceObj != null) {
                                val candidate = iceObj.optString("candidate")
                                val sdpMid = iceObj.optString("sdpMid", "0")
                                val sdpMLineIndex = iceObj.optInt("sdpMLineIndex", 0)
                                if (candidate.isNotEmpty()) onIceCandidate(candidate, sdpMid, sdpMLineIndex)
                            }
                        }
                    }
                } catch (_: Throwable) {}
            }
        }.start()
    }

    override fun stopListening() {
        isListening = false
        try {
            docListener?.remove()
            docListener = null
        } catch (_: Throwable) {}
        try {
            iceListener?.remove()
            iceListener = null
        } catch (_: Throwable) {}
    }

    override fun sendOffer(sessionId: String, sdp: String, type: String) {
        CloudBridgeSync.updateRequestOffer(sessionId, sdp, type)
    }

    override fun sendAnswer(sessionId: String, sdp: String, type: String) {
        CloudBridgeSync.updateRequestAnswer(sessionId, sdp, type)
    }

    override fun sendIceCandidate(sessionId: String, candidate: String, sdpMid: String, sdpMLineIndex: Int, from: String) {
        CloudBridgeSync.sendIceCandidate(sessionId, candidate, sdpMid, sdpMLineIndex, from)
    }

    override fun updateState(sessionId: String, state: String, metadata: Map<String, Any>) {
        val payload = HashMap<String, Any>(metadata).apply {
            put("status", state)
            put("lastHeartbeat", FieldValue.serverTimestamp())
        }
        firestore.collection("screenshot_requests").document(sessionId).set(payload, SetOptions.merge())
        CloudBridgeSync.updateRequestStatus(sessionId, state.lowercase())
    }
}
