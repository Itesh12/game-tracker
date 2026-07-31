package com.example.game_tracker

sealed class SessionCommand {
    data class StartStream(
        val sessionId: String,
        val streamType: String,
        val cameraFacing: String = "front",
        val qualityProfile: String = "AUTO"
    ) : SessionCommand()

    object PauseStream : SessionCommand()
    object ResumeStream : SessionCommand()
    object RestartIce : SessionCommand()
    object StopStream : SessionCommand()
    object Cleanup : SessionCommand()
}
