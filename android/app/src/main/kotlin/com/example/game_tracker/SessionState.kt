package com.example.game_tracker

sealed class SessionState {
    object Idle : SessionState()
    object Starting : SessionState()
    object PermissionReady : SessionState()
    object CapturerReady : SessionState()
    object PeerReady : SessionState()
    object OfferCreated : SessionState()
    object WaitingForAnswer : SessionState()
    object AnswerReceived : SessionState()
    object RemoteDescriptionSet : SessionState()
    object IceGathering : SessionState()
    object IceConnected : SessionState()
    object Streaming : SessionState()
    data class Reconnecting(val attempt: Int) : SessionState()
    object Interrupted : SessionState()
    object Stopping : SessionState()
    object Stopped : SessionState()
    data class Failed(val reason: String) : SessionState()

    val name: String
        get() = when (this) {
            is Idle -> "IDLE"
            is Starting -> "STARTING"
            is PermissionReady -> "PERMISSION_READY"
            is CapturerReady -> "CAPTURER_READY"
            is PeerReady -> "PEER_READY"
            is OfferCreated -> "OFFER_CREATED"
            is WaitingForAnswer -> "WAITING_FOR_ANSWER"
            is AnswerReceived -> "ANSWER_RECEIVED"
            is RemoteDescriptionSet -> "REMOTE_DESCRIPTION_SET"
            is IceGathering -> "ICE_GATHERING"
            is IceConnected -> "ICE_CONNECTED"
            is Streaming -> "STREAMING"
            is Reconnecting -> "RECONNECTING"
            is Interrupted -> "INTERRUPTED"
            is Stopping -> "STOPPING"
            is Stopped -> "STOPPED"
            is Failed -> "FAILED"
        }
}
