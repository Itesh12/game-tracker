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
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.ListenerRegistration
import java.util.*

class WebRtcPublisherService : Service() {

    companion object {
        private const val TAG = "WebRtcPublisher"
        private const val NOTIFICATION_ID = 1004
        private const val CHANNEL_ID = "WebRtcPublisherChannel"
    }

    private var peerConnectionFactory: PeerConnectionFactory? = null
    private var peerConnection: PeerConnection? = null
    private var localVideoTrack: VideoTrack? = null
    private var localAudioTrack: AudioTrack? = null
    private var videoCapturer: VideoCapturer? = null
    private var surfaceTextureHelper: SurfaceTextureHelper? = null
    private val firestore = FirebaseFirestore.getInstance()
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
        initializePeerFactory()
    }

    private fun initializePeerFactory() {
        try {
            eglBase = EglBase.create()
            val options = PeerConnectionFactory.InitializationOptions.builder(this).createInitializationOptions()
            PeerConnectionFactory.initialize(options)
            val encoderFactory = DefaultVideoEncoderFactory(eglBase?.eglBaseContext, true, true)
            val decoderFactory = DefaultVideoDecoderFactory(eglBase?.eglBaseContext)
            peerConnectionFactory = PeerConnectionFactory.builder()
                .setVideoEncoderFactory(encoderFactory)
                .setVideoDecoderFactory(decoderFactory)
                .createPeerConnectionFactory()
        } catch (e: Throwable) {
            Log.e(TAG, "Error initializing PeerConnectionFactory: ${e.message}", e)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        requestId = intent?.getStringExtra("requestId")
        val cameraFacing = intent?.getStringExtra("cameraFacing") ?: "front"
        val requestType = intent?.getStringExtra("requestType") ?: "camera_stream"

        val resultDataFromIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent?.getParcelableExtra("resultData", Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent?.getParcelableExtra<Intent>("resultData")
        }
        val savedProjection = MediaProjectionStore.load(this)
        val resultData = resultDataFromIntent ?: savedProjection.second ?: MainActivity.mediaProjectionResultData

        // 1. MUST start foreground service with the correct foreground type FIRST on Android Q / Android 14+
        val notification = createNotification()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                if (requestType == "camera_stream" && ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA)
                } else if (requestType == "screen_share" && resultData != null) {
                    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to start foreground service: ${e.message}", e)
        }

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

        createPeerConnection()
        startLocalCapture(requestType, cameraFacing, resultData)

        peerConnection?.createOffer(object : SdpObserver {
            override fun onCreateSuccess(desc: SessionDescription?) {
                peerConnection?.setLocalDescription(object : SdpObserver {
                    override fun onSetSuccess() {}
                    override fun onSetFailure(p0: String?) {
                        Log.e(TAG, "setLocalDescription failure: $p0")
                    }
                    override fun onCreateSuccess(p0: SessionDescription?) {}
                    override fun onCreateFailure(p0: String?) {}
                }, desc)

                requestId?.let { rid ->
                    firestore.collection("screenshot_requests").document(rid).set(mapOf(
                        "offer" to mapOf(
                            "sdp" to desc?.description,
                            "type" to desc?.type?.canonicalForm()
                        ),
                        "status" to "offer_created"
                    ), com.google.firebase.firestore.SetOptions.merge())

                    watchForAnswerAndRemoteIce(rid)
                }
            }
            override fun onCreateFailure(p0: String?) {
                Log.e(TAG, "createOffer failure: $p0")
                markFailed(requestId, "WebRTC createOffer failed: $p0")
            }
            override fun onSetSuccess() {}
            override fun onSetFailure(p0: String?) {}
        }, MediaConstraints())

        return START_STICKY
    }

    private fun createPeerConnection() {
        val iceServers = listOf(
            PeerConnection.IceServer.builder("stun:stun.l.google.com:19302").createIceServer(),
            PeerConnection.IceServer.builder("stun:stun1.l.google.com:19302").createIceServer()
        )
        val rtcConfig = PeerConnection.RTCConfiguration(iceServers)
        peerConnection = peerConnectionFactory?.createPeerConnection(rtcConfig, object : PeerConnection.Observer {
            override fun onIceCandidate(candidate: IceCandidate) {
                requestId?.let { rid ->
                    firestore.collection("screenshot_requests").document(rid).collection("iceCandidates")
                        .add(mapOf(
                            "candidate" to candidate.sdp,
                            "sdpMid" to candidate.sdpMid,
                            "sdpMLineIndex" to candidate.sdpMLineIndex,
                            "from" to "publisher"
                        ))
                }
            }
            override fun onAddStream(stream: MediaStream?) {}
            override fun onDataChannel(dc: DataChannel?) {}
            override fun onIceConnectionReceivingChange(p0: Boolean) {}
            override fun onIceConnectionChange(p0: PeerConnection.IceConnectionState?) {}
            override fun onIceGatheringChange(p0: PeerConnection.IceGatheringState?) {}
            override fun onRemoveStream(p0: MediaStream?) {}
            override fun onSignalingChange(p0: PeerConnection.SignalingState?) {}
            override fun onIceCandidatesRemoved(p0: Array<out IceCandidate>?) {}
            override fun onRenegotiationNeeded() {}
            override fun onAddTrack(receiver: RtpReceiver?, streams: Array<out MediaStream>?) {}
        })
    }

    private fun watchForAnswerAndRemoteIce(rid: String) {
        docListener = firestore.collection("screenshot_requests").document(rid)
            .addSnapshotListener { snapshot: DocumentSnapshot?, error ->
                if (error != null || snapshot == null) return@addSnapshotListener
                if (snapshot.contains("answer")) {
                    val answer = snapshot.get("answer") as? Map<*, *>
                    val sdp = answer?.get("sdp") as? String
                    val type = answer?.get("type") as? String
                    if (!sdp.isNullOrEmpty() && !type.isNullOrEmpty()) {
                        try {
                            val sd = SessionDescription(SessionDescription.Type.fromCanonicalForm(type), sdp)
                            peerConnection?.setRemoteDescription(object : SdpObserver {
                                override fun onSetSuccess() {}
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
            }

        iceListener = firestore.collection("screenshot_requests").document(rid)
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
    }

    private fun startLocalCapture(requestType: String, facing: String, resultData: Intent?) {
        try {
            if (requestType == "screen_share" && resultData != null) {
                try {
                    videoCapturer = ScreenCapturerAndroid(resultData, object : android.media.projection.MediaProjection.Callback() {})
                } catch (e: Throwable) {
                    Log.e(TAG, "ScreenCapturerAndroid creation failed: ${e.message}", e)
                }
            }

            if (videoCapturer == null) {
                val enumerator = Camera2Enumerator(this)
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
                    videoCapturer = enumerator.createCapturer(targetName, null)
                }
            }

            if (videoCapturer == null) {
                Log.e(TAG, "No video capturer could be initialized")
                markFailed(requestId, "Failed to initialize video capturer")
                return
            }

            surfaceTextureHelper = SurfaceTextureHelper.create("WebRTC_Thread", eglBase?.eglBaseContext)
            val videoSource = peerConnectionFactory?.createVideoSource(false)
            videoCapturer?.initialize(surfaceTextureHelper, applicationContext, videoSource?.capturerObserver)
            videoCapturer?.startCapture(640, 480, 25)
            localVideoTrack = peerConnectionFactory?.createVideoTrack("ARDAMSv0", videoSource)
            if (localVideoTrack != null) {
                peerConnection?.addTrack(localVideoTrack)
            }

            if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                try {
                    val audioConstraints = MediaConstraints()
                    val audioSource = peerConnectionFactory?.createAudioSource(audioConstraints)
                    localAudioTrack = peerConnectionFactory?.createAudioTrack("ARDAMSa0", audioSource)
                    if (localAudioTrack != null) {
                        peerConnection?.addTrack(localAudioTrack)
                    }
                } catch (e: Throwable) {
                    Log.e(TAG, "Error adding audio track: ${e.message}")
                }
            }
        } catch (e: Throwable) {
            Log.e(TAG, "startLocalCapture exception: ${e.message}", e)
            markFailed(requestId, "Video capture error: ${e.message}")
        }
    }

    private fun markFailed(requestId: String?, reason: String) {
        if (!requestId.isNullOrEmpty()) {
            try {
                firestore.collection("screenshot_requests").document(requestId).update(
                    mapOf(
                        "status" to "failed",
                        "error" to reason,
                        "failureReason" to reason
                    )
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error updating Firestore failure status: ${e.message}")
            }
        }
    }

    override fun onDestroy() {
        try {
            videoCapturer?.stopCapture()
            videoCapturer?.dispose()
            videoCapturer = null
        } catch (e: Exception) {}
        try {
            surfaceTextureHelper?.dispose()
            surfaceTextureHelper = null
        } catch (e: Exception) {}
        try {
            docListener?.remove()
        } catch (e: Exception) {}
        try {
            iceListener?.remove()
        } catch (e: Exception) {}

        try {
            peerConnection?.close()
            peerConnection = null
        } catch (e: Exception) {}
        try {
            peerConnectionFactory?.dispose()
            peerConnectionFactory = null
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
            .setContentTitle("Live Stream Service")
            .setContentText("Publishing live stream...")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setOngoing(true)
            .setSilent(true)
            .setLocalOnly(true)
            .build()
    }
}
