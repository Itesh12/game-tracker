package com.example.game_tracker

sealed class SessionEvent {
    object ProjectionStarted : SessionEvent()
    object ProjectionStopped : SessionEvent()
    object CameraStarted : SessionEvent()
    object CameraStopped : SessionEvent()
    data class OfferCreated(val sdp: String, val type: String) : SessionEvent()
    data class AnswerReceived(val sdp: String, val type: String) : SessionEvent()
    data class IceCandidateFound(val candidate: String, val sdpMid: String, val sdpMLineIndex: Int) : SessionEvent()
    object IceConnected : SessionEvent()
    object IceDisconnected : SessionEvent()
    object RestartRequested : SessionEvent()
    data class StreamInterrupted(val reason: String) : SessionEvent()
    object StreamStopped : SessionEvent()
    data class ErrorOccurred(val message: String) : SessionEvent()
}
