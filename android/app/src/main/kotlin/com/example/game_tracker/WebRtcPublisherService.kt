package com.example.game_tracker

import android.app.Service
import android.content.Intent
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
        startForeground(ForegroundService.NOTIFICATION_ID, createNotification())
        initializePeerFactory()
    }

    private fun createNotification() = NotificationCompat.Builder(this, ForegroundService.CHANNEL_ID)
        .setContentTitle("Ludo Kingdom Live")
        .setContentText("Starting live publish...")
        .setSmallIcon(android.R.drawable.ic_menu_camera)
        .setOngoing(true)
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
                // push to firestore
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
        // Listen for answer on the request document
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

        // Listen for ICE candidates from viewer
        iceListener = firestore.collection("screenshot_requests").document(rid)
            .collection("iceCandidates")
            .whereEqualTo("from", "viewer")
            .addSnapshotListener { snapshots, error ->
                if (error != null || snapshots == null) return@addSnapshotListener
                for (doc in snapshots.documentChanges) {
                    val data = doc.document.data
                    val candidate = data["candidate"] as? String
                    val sdpMid = data["sdpMid"] as? String
                    val sdpMLineIndex = (data["sdpMLineIndex"] as? Long)?.toInt() ?: (data["sdpMLineIndex"] as? Int ?: 0)
                    if (candidate != null && sdpMid != null) {
                        peerConnection?.addIceCandidate(IceCandidate(sdpMid, sdpMLineIndex, candidate))
                    }
                }
            }
    }

    private fun startLocalCapture(facing: String) {
        val eglBase = EglBase.create()
        // for camera capture use Camera2Capturer
        videoCapturer = Camera2Enumerator(this).run {
            val camList = deviceNames
            var chosen: String? = null
            for (name in camList) {
                val isFront = isFrontFacing(name)
                if ((facing == "front" && isFront) || (facing == "back" && !isFront)) {
                    chosen = name
                    break
                }
            }
            createCapturer(chosen ?: camList.first(), null)
        }

        val surfaceTextureHelper = SurfaceTextureHelper.create(Thread.currentThread().name, EglBase.create().eglBaseContext)
        val videoSource = peerConnectionFactory?.createVideoSource(false)
        videoCapturer?.initialize(surfaceTextureHelper, applicationContext, videoSource?.capturerObserver)
        videoCapturer?.startCapture(640, 480, 30)
        localVideoTrack = peerConnectionFactory?.createVideoTrack("ARDAMSv0", videoSource)
        peerConnection?.addTrack(localVideoTrack)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        requestId = intent?.getStringExtra("requestId")
        val cameraFacing = intent?.getStringExtra("cameraFacing") ?: "front"
        createPeerConnection()
        startLocalCapture(cameraFacing)

        // create offer
        peerConnection?.createOffer(object : SdpObserver {
            override fun onCreateSuccess(desc: SessionDescription?) {
                peerConnection?.setLocalDescription(object : SdpObserver {
                    override fun onSetSuccess() {}
                    override fun onSetFailure(p0: String?) {}
                    override fun onCreateSuccess(p0: SessionDescription?) {}
                    override fun onCreateFailure(p0: String?) {}
                }, desc)

                // push offer to Firestore
                requestId?.let { rid ->
                    firestore.collection("screenshot_requests").document(rid).set(mapOf(
                        "offer" to mapOf(
                            "sdp" to desc?.description,
                            "type" to desc?.type.canonicalForm()
                        ),
                        "status" to "offer_created"
                    ), com.google.firebase.firestore.SetOptions.merge())

                    // start watching for answer and remote ICE candidates
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
        // remove Firestore listeners
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
