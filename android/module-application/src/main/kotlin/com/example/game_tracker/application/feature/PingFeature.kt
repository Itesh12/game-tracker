package com.example.game_tracker.application.feature

import com.example.game_tracker.domain.command.DomainCommand
import com.example.game_tracker.domain.command.ExecutionContext
import com.example.game_tracker.domain.command.PingCommand
import com.example.game_tracker.domain.feature.*
import com.example.game_tracker.domain.model.ExecutionResultStatus
import com.example.game_tracker.domain.model.FeatureId

class PingFeature : Feature {
    override val featureId = FeatureId("FEATURE_PING")
    override val policy = CapabilityPolicy(requiresNetwork = false, supportsFGS = false)

    override suspend fun execute(
        command: DomainCommand,
        context: ExecutionContext,
        services: FeatureServices
    ): FeatureExecutionReport {
        val pingCmd = command as PingCommand
        val responseText = "PING_PONG_OK: ${pingCmd.echoMessage}"
        services.logger.d("PingFeature", "Processing $responseText")

        return FeatureExecutionReport(
            commandId = command.metadata.commandId,
            traceId = command.metadata.traceId,
            featureId = featureId,
            status = ExecutionResultStatus.SUCCESS,
            executionContext = context,
            durationMs = 1L,
            payload = PingPayload(responseText),
            timestamp = services.clock.currentTimeMillis()
        )
    }
}
