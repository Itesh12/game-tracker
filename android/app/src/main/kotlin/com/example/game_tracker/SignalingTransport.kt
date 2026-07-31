package com.example.game_tracker

interface SignalingReader {
    fun startListening(sessionId: String, onOffer: (String, String) -> Unit, onAnswer: (String, String) -> Unit, onIceCandidate: (String, String, Int) -> Unit)
    fun stopListening()
}

interface SignalingWriter {
    fun sendOffer(sessionId: String, sdp: String, type: String)
    fun sendAnswer(sessionId: String, sdp: String, type: String)
    fun sendIceCandidate(sessionId: String, candidate: String, sdpMid: String, sdpMLineIndex: Int, from: String)
    fun updateState(sessionId: String, state: String, metadata: Map<String, Any> = emptyMap())
}

interface SignalingTransport : SignalingReader, SignalingWriter
