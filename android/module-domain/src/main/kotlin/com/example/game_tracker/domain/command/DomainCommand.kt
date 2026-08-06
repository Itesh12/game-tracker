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
