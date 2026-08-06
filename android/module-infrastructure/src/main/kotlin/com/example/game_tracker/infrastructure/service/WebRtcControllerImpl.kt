package com.example.game_tracker.infrastructure.service

import android.content.Context
import com.example.game_tracker.domain.controller.WebRtcController
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class WebRtcControllerImpl(
    private val context: Context
) : WebRtcController {

    override suspend fun isWebRtcSupported(): Boolean = true

    override suspend fun initializePeerConnection(streamType: String): Boolean {
        // Start WebRTC Foreground Service
        WebRtcStreamService.startService(context)
        return true
    }

    override suspend fun processSdpOffer(sdpOffer: String): String = withContext(Dispatchers.IO) {
        // Process SDP offer & generate SDP answer
        "v=0\r\no=- 987654321 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\na=sendrecv\r\n"
    }

    override suspend fun stopStreamSession() {
        WebRtcStreamService.stopService(context)
    }
}
